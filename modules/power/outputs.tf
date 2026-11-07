output "client_id" {
  description = "What staging-power.yml signs in as (tcm's environment.env, POWER_CLIENT_ID)."
  value       = azurerm_user_assigned_identity.power.client_id
}
