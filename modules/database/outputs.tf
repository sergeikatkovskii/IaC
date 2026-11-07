output "id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "max_user_connections" {
  description = "DB_MAX_USER_CONNECTIONS in the overlay; T-002's pool test holds the manifests to it."
  value       = local.max_user_connections[var.sku_name]
}

output "admin_login" {
  value = var.admin_login
}

output "admin_secret_name" {
  value = var.admin_secret_name
}
