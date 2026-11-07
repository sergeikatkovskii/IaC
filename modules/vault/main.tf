# KAT-648 T-005 — a vault (ARD-018). Rights are role assignments, the network is
# default-deny, and a deleted vault cannot be purged before 90 days.

resource "azurerm_key_vault" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = var.soft_delete_retention_days

  public_network_access_enabled = true

  network_acls {
    default_action             = "Deny"
    bypass                     = "None"
    ip_rules                   = var.operator_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "reader" {
  for_each = var.reader_principal_ids

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "writer" {
  for_each = var.writer_principal_ids

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

resource "time_sleep" "rbac" {
  depends_on      = [azurerm_role_assignment.reader, azurerm_role_assignment.writer]
  create_duration = "${var.rbac_propagation_seconds}s"
}
