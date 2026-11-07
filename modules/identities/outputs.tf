output "unit_client_ids" {
  description = "unit => client id, for each service account's azure.workload.identity/client-id annotation."
  value       = { for k, v in azurerm_user_assigned_identity.unit : k => v.client_id }
}

output "unit_principal_ids" {
  value = { for k, v in azurerm_user_assigned_identity.unit : k => v.principal_id }
}

output "pipeline_client_id" {
  value = azurerm_user_assigned_identity.pipeline.client_id
}

output "pipeline_principal_id" {
  value = azurerm_user_assigned_identity.pipeline.principal_id
}
