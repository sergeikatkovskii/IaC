# What the product needs to send, which IaC/scripts/overlay_values.py writes into
# tcm's environment.env (SMTP_HOST, SMTP_USERNAME, MAIL_FROM). The password is the
# vault's, never an output.

output "smtp_host" {
  description = "Azure Communication Services' SMTP host, port 587, STARTTLS."
  value       = "smtp.azurecomm.net"
}

output "smtp_username" {
  description = "The resource's name, the application's id and the tenant's, joined by dots (Microsoft)."
  value       = "${azurerm_communication_service.this.name}.${azuread_application.smtp.client_id}.${data.azurerm_client_config.current.tenant_id}"
}

output "mail_from" {
  value = "${azurerm_email_communication_service_domain_sender_username.this.name}@${var.domain}"
}

output "smtp_app_client_id" {
  description = "Whose client secret is the SMTP password: the founder makes it after the apply."
  value       = azuread_application.smtp.client_id
}

output "email_service_name" {
  description = "For the domain's verification, run once the zone is delegated."
  value       = azurerm_email_communication_service.this.name
}
