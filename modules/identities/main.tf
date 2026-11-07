# KAT-648 T-005 — who signs in to Azure as what, and from where. No password and no
# client secret exists anywhere here: every sign-in is a federated token exchange.

locals {
  token_audience = "api://AzureADTokenExchange"
  identities     = toset(concat(var.units, ["db-bootstrap"]))
}

resource "azurerm_user_assigned_identity" "unit" {
  for_each = local.identities

  name                = "${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Each unit signs in as exactly its own service account.
resource "azurerm_federated_identity_credential" "unit" {
  for_each = toset(var.units)

  name                      = "${each.key}-service-account"
  user_assigned_identity_id = azurerm_user_assigned_identity.unit[each.key].id
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.namespace}:${each.key}"
  audience                  = [local.token_audience]
}

resource "azurerm_federated_identity_credential" "db_bootstrap" {
  count = var.first_boot_open ? 1 : 0

  name                      = "db-bootstrap-service-account"
  user_assigned_identity_id = azurerm_user_assigned_identity.unit["db-bootstrap"].id
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.namespace}:db-bootstrap"
  audience                  = [local.token_audience]
}

# The pipeline: a GitHub job in this repository's environment, which waits for the
# founder's approval, and nothing else.
resource "azurerm_user_assigned_identity" "pipeline" {
  name                = "${var.name_prefix}-pipeline"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "pipeline" {
  name                      = "github-${var.github_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.pipeline.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_repository}:environment:${var.github_environment}"
  audience                  = [local.token_audience]
}

# At cluster scope the pipeline may only fetch its sign-in configuration.
resource "azurerm_role_assignment" "pipeline_cluster_user" {
  scope                = var.cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_user_assigned_identity.pipeline.principal_id
  principal_type       = "ServicePrincipal"
}

# Inside the cluster it writes in one namespace, and cannot create a namespace or
# grant a right (KAT-648 §8 Q10: Ansible sets up, the pipeline deploys).
resource "azurerm_role_assignment" "pipeline_writer" {
  scope                = "${var.cluster_id}/namespaces/${var.namespace}"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azurerm_user_assigned_identity.pipeline.principal_id
  principal_type       = "ServicePrincipal"
}
