# KAT-648 T-005 — staging turned off on a schedule and on demand (the founder,
# 2026-11-07), by .github/workflows/staging-power.yml in tcm. That job runs unattended,
# at night, so unlike a release it cannot wait for the founder's approval; what it signs
# in as may read, start and stop the cluster and the database server, and nothing else.
# It holds no right inside the cluster or the database, reads no secret, and changes no
# setting: the worst a stolen sign-in does is turn staging off or on.

resource "azurerm_user_assigned_identity" "power" {
  name                = "${var.name_prefix}-power"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "power" {
  name                      = "github-${var.github_environment}-power"
  user_assigned_identity_id = azurerm_user_assigned_identity.power.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_repository}:environment:${var.github_environment}-power"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_definition" "power" {
  name        = "${var.name_prefix} power"
  scope       = var.resource_group_id
  description = "Read, start and stop ${var.name_prefix}'s cluster and database server, and nothing else (KAT-648 T-005)."

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/start/action",
      "Microsoft.ContainerService/managedClusters/stop/action",
      "Microsoft.DBforPostgreSQL/flexibleServers/read",
      "Microsoft.DBforPostgreSQL/flexibleServers/start/action",
      "Microsoft.DBforPostgreSQL/flexibleServers/stop/action",
    ]
    not_actions  = []
    data_actions = []
  }

  assignable_scopes = [var.resource_group_id]
}

resource "azurerm_role_assignment" "cluster" {
  scope              = var.cluster_id
  role_definition_id = azurerm_role_definition.power.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.power.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "server" {
  scope              = var.server_id
  role_definition_id = azurerm_role_definition.power.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.power.principal_id
  principal_type     = "ServicePrincipal"
}
