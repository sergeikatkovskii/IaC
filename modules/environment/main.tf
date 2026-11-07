# KAT-648 T-005 — one environment: everything ARD-059 says Terraform creates. The
# env roots call this once with their own values, so staging and production differ
# by tfvars and never by an edited copy.

data "azurerm_client_config" "current" {}

# KAT-648 T-005: the subscription the provider was pointed at. Its id is given at run
# time and never committed (IaC is public); its name is committed, and checked.
data "azurerm_subscription" "current" {}

locals {
  prefix = "katachi-${var.environment}"
  short  = var.environment == "production" ? "prd" : "stg"

  tags = merge({
    product     = "katachi"
    environment = var.environment
    managed-by  = "terraform"
  }, var.tags)

  # Every unit that reads the app vault, each as its own identity. KAT-648 T-003
  # added the migration Job and Redis, which the CSI driver fetches for as well.
  app_units = ["backend", "worker", "scheduler", "mcp", "migrate", "redis"]

  cluster_admins = length(var.cluster_admin_object_ids) > 0 ? toset(var.cluster_admin_object_ids) : toset([data.azurerm_client_config.current.object_id])
}

# The registry, the vaults, the storage account and the server need names unique
# across all of Azure.
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags

  lifecycle {
    precondition {
      condition     = data.azurerm_subscription.current.display_name == var.subscription_name
      error_message = "The provider is pointed at the subscription \"${data.azurerm_subscription.current.display_name}\", and ${var.environment} lives in \"${var.subscription_name}\". Nothing was planned."
    }
  }
}

module "network" {
  source = "../network"

  name_prefix         = local.prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = local.tags
}

module "logs" {
  source = "../logs"

  name                = "${local.prefix}-logs"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

module "cluster" {
  source = "../cluster"

  name                       = "${local.prefix}-aks"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = var.location
  dns_prefix                 = local.prefix
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  kubernetes_version         = var.kubernetes_version
  sku_tier                   = var.cluster_sku_tier
  node_vm_size               = var.node_vm_size
  node_min_count             = var.node_min_count
  node_max_count             = var.node_max_count
  node_subnet_id             = module.network.aks_subnet_id
  log_analytics_workspace_id = module.logs.workspace_id
  tags                       = local.tags
}

# A person administers the cluster (KAT-648 §8 Q10): installs the platform, makes
# the namespace and grants the rights the units hold.
resource "azurerm_role_assignment" "cluster_admin" {
  for_each = local.cluster_admins

  scope                = module.cluster.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}

module "identities" {
  source = "../identities"

  name_prefix         = local.prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  oidc_issuer_url     = module.cluster.oidc_issuer_url
  cluster_id          = module.cluster.id
  units               = local.app_units
  first_boot_open     = var.first_boot_open
  github_repository   = var.github_repository
  github_environment  = var.environment
  tags                = local.tags
}

module "registry" {
  source = "../registry"

  name                = "katachi${local.short}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  sku                 = var.registry_sku
  pull_principal_ids  = { kubelet = module.cluster.kubelet_object_id }
  push_principal_ids  = { pipeline = module.identities.pipeline_principal_id }
  tags                = local.tags
}

# Two vaults (KAT-648 T-005): the units read the app vault, and only db-bootstrap
# reads the admin vault, which holds the database administrator's password.
module "vault_app" {
  source = "../vault"

  name                = "kat-${local.short}-app-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  allowed_subnet_ids  = [module.network.aks_subnet_id]
  operator_ip_ranges  = var.operator_ip_ranges
  # db-bootstrap too (KAT-648 T-004): first boot makes the role database-url names.
  # Its federated credential exists only while first_boot_open, so that read does too.
  reader_principal_ids = merge(
    { for u in local.app_units : u => module.identities.unit_principal_ids[u] },
    { "db-bootstrap" = module.identities.unit_principal_ids["db-bootstrap"] },
  )
  writer_principal_ids = { operator = data.azurerm_client_config.current.object_id }
  tags                 = local.tags
}

module "vault_admin" {
  source = "../vault"

  name                 = "kat-${local.short}-adm-${random_string.suffix.result}"
  resource_group_name  = azurerm_resource_group.this.name
  location             = var.location
  tenant_id            = data.azurerm_client_config.current.tenant_id
  allowed_subnet_ids   = [module.network.aks_subnet_id]
  operator_ip_ranges   = var.operator_ip_ranges
  reader_principal_ids = { "db-bootstrap" = module.identities.unit_principal_ids["db-bootstrap"] }
  writer_principal_ids = { operator = data.azurerm_client_config.current.object_id }
  tags                 = local.tags
}

module "database" {
  source = "../database"

  name                   = "${local.prefix}-pg-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.this.name
  location               = var.location
  sku_name               = var.postgres_sku_name
  delegated_subnet_id    = module.network.postgres_subnet_id
  private_dns_zone_id    = module.network.postgres_private_dns_zone_id
  admin_vault_id         = module.vault_admin.id
  admin_password_version = var.postgres_admin_password_version
  tags                   = local.tags
}

module "storage" {
  source = "../storage"

  name                = "katachi${local.short}data${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  allowed_subnet_ids  = [module.network.aks_subnet_id]
  operator_ip_ranges  = var.operator_ip_ranges
  tags                = local.tags
}

module "edge" {
  source = "../edge"

  name                 = "${local.prefix}-gateway"
  resource_group_name  = azurerm_resource_group.this.name
  location             = var.location
  app_host             = var.app_host
  mcp_host             = var.mcp_host
  admin_host           = var.admin_host
  dns_zone_name        = var.dns_zone_name
  cluster_principal_id = module.cluster.principal_id
  tags                 = local.tags
}

module "storage_detection" {
  source = "../storage-detection"

  environment         = var.environment
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  storage_account_id  = module.storage.id

  create_workspace           = false
  log_analytics_workspace_id = module.logs.workspace_id
  log_retention_days         = var.log_retention_days

  enable_sas_alert      = var.enable_sas_alert
  alert_email_receivers = var.alert_email_receivers
  alert_webhook_url     = var.alert_webhook_url
  skip_query_validation = var.skip_query_validation
}

# KAT-648 T-005: staging's mail (§8 Q5), from the domain the zone above serves, which is
# where Azure verifies it. An environment whose DNS lives elsewhere has none yet.
module "mail" {
  source = "../mail"
  count  = var.dns_zone_name == "" ? 0 : 1

  name_prefix         = local.prefix
  resource_group_name = azurerm_resource_group.this.name
  domain              = var.dns_zone_name
  zone_name           = module.edge.zone_name
  tags                = local.tags
}
