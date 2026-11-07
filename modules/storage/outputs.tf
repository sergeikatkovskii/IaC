output "id" {
  value = azurerm_storage_account.this.id
}

output "name" {
  value = azurerm_storage_account.this.name
}

output "container_name" {
  value = azurerm_storage_container.attachments.name
}

# KAT-418 T-003: where the units reach storage as themselves, and where they hold the role.
output "blob_endpoint" {
  description = "The account's blob address: STORAGE_ACCOUNT_URL in tcm's environment.env."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "container_scope" {
  description = "Where the units hold the storage role: T-005's revocation runbook removes an assignment at this scope."
  value       = local.container_scope
}

# Who holds the role, by name: tested at the composition, where it matters.
output "holder_names" {
  value = sort(keys(var.data_principal_ids))
}
