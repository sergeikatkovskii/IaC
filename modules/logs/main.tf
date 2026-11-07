# KAT-648 T-005 — one workspace per environment: the cluster's audit log and the
# storage alerts (KAT-417) read and write here.

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb

  # Everything that writes here signs in with Entra ID; a shared key is one more
  # secret to leak.
  local_authentication_enabled = false

  tags = var.tags
}
