output "resource_group_name" {
  value       = azurerm_resource_group.shared.name
  description = "Feed this to each env root's backend.tf as resource_group_name."
}

output "state_account_name" {
  value       = azurerm_storage_account.tfstate.name
  description = "Feed this to each env root's backend.tf as storage_account_name."
}

output "state_container_name" {
  value       = azurerm_storage_container.tfstate.name
  description = "Feed this to each env root's backend.tf as container_name."
}
