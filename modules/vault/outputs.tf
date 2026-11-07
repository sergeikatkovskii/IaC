# The id waits for the role assignments to propagate, so a secret written through
# it is not refused for a right that is still on its way.
output "id" {
  value      = azurerm_key_vault.this.id
  depends_on = [time_sleep.rbac]
}

output "name" {
  value = azurerm_key_vault.this.name
}

output "vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

# Who may read it, by name (KAT-648 T-004): tested at the composition, where it matters.
output "reader_names" {
  value = sort(keys(var.reader_principal_ids))
}
