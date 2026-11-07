# What tcm needs. IaC/scripts/overlay_values.py turns these into
# tcm/k8s/overlays/<env>/environment.env, so no identifier is typed twice.

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "registry_login_server" {
  value = module.registry.login_server
}

output "key_vault_name" {
  description = "The app vault, which the units read."
  value       = module.vault_app.name
}

output "admin_key_vault_name" {
  description = "The admin vault, which only db-bootstrap reads."
  value       = module.vault_admin.name
}

output "unit_client_ids" {
  value = module.identities.unit_client_ids
}

output "pipeline_client_id" {
  value = module.identities.pipeline_client_id
}

output "cluster_name" {
  value = module.cluster.name
}

output "cluster_resource_group" {
  value = azurerm_resource_group.this.name
}

output "oidc_issuer_url" {
  value = module.cluster.oidc_issuer_url
}

output "pod_cidr" {
  description = "TRUSTED_PROXY_CIDR: the gateway's pods live in this range (KAT-S9)."
  value       = module.cluster.pod_cidr
}

output "gateway_ip_name" {
  value = module.edge.ip_name
}

output "gateway_ip_resource_group" {
  value = module.edge.ip_resource_group
}

output "gateway_ip_address" {
  value = module.edge.ip_address
}

output "dns_name_servers" {
  value = module.edge.name_servers
}

output "app_host" {
  value = var.app_host
}

output "mcp_host" {
  value = var.mcp_host
}

output "postgres_fqdn" {
  value = module.database.fqdn
}

output "postgres_max_user_connections" {
  value = module.database.max_user_connections
}

output "postgres_admin_login" {
  value = module.database.admin_login
}

output "postgres_admin_secret_name" {
  value = module.database.admin_secret_name
}

output "storage_account_name" {
  value = module.storage.name
}

output "storage_container_name" {
  value = module.storage.container_name
}

output "log_workspace_id" {
  value = module.logs.workspace_id
}

output "query_anonymous_success" {
  value = module.storage_detection.query_anonymous_success
}

output "query_container_list" {
  value = module.storage_detection.query_container_list
}

output "query_sas_used" {
  value = module.storage_detection.query_sas_used
}
