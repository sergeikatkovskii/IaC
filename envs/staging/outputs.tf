# Everything tcm needs, read by IaC/scripts/overlay_values.py to write
# tcm/k8s/overlays/staging/environment.env. No identifier is typed twice.

output "subscription_id" {
  value = module.katachi.subscription_id
}

output "tenant_id" {
  value = module.katachi.tenant_id
}

output "resource_group_name" {
  value = module.katachi.resource_group_name
}

output "registry_login_server" {
  value = module.katachi.registry_login_server
}

output "key_vault_name" {
  value = module.katachi.key_vault_name
}

output "admin_key_vault_name" {
  value = module.katachi.admin_key_vault_name
}

output "unit_client_ids" {
  value = module.katachi.unit_client_ids
}

output "pipeline_client_id" {
  value = module.katachi.pipeline_client_id
}

output "pipeline_principal_id" {
  description = "The pipeline's object id: setup.yml binds the release Role to it (KAT-648 T-005)."
  value       = module.katachi.pipeline_principal_id
}

output "cluster_name" {
  value = module.katachi.cluster_name
}

output "cluster_resource_group" {
  value = module.katachi.cluster_resource_group
}

output "oidc_issuer_url" {
  value = module.katachi.oidc_issuer_url
}

output "pod_cidr" {
  value = module.katachi.pod_cidr
}

output "gateway_ip_name" {
  value = module.katachi.gateway_ip_name
}

output "gateway_ip_resource_group" {
  value = module.katachi.gateway_ip_resource_group
}

output "gateway_ip_address" {
  value = module.katachi.gateway_ip_address
}

output "dns_name_servers" {
  value = module.katachi.dns_name_servers
}

output "app_host" {
  value = module.katachi.app_host
}

output "mcp_host" {
  value = module.katachi.mcp_host
}

output "admin_host" {
  value = module.katachi.admin_host
}

output "postgres_fqdn" {
  value = module.katachi.postgres_fqdn
}

output "postgres_max_user_connections" {
  value = module.katachi.postgres_max_user_connections
}

output "postgres_admin_login" {
  value = module.katachi.postgres_admin_login
}

output "postgres_admin_secret_name" {
  value = module.katachi.postgres_admin_secret_name
}

output "storage_account_name" {
  value = module.katachi.storage_account_name
}

output "storage_container_name" {
  value = module.katachi.storage_container_name
}

output "log_workspace_id" {
  value = module.katachi.log_workspace_id
}

output "query_anonymous_success" {
  value = module.katachi.query_anonymous_success
}

output "query_container_list" {
  value = module.katachi.query_container_list
}

output "query_sas_used" {
  value = module.katachi.query_sas_used
}

output "smtp_host" {
  value = module.katachi.smtp_host
}

output "smtp_username" {
  value = module.katachi.smtp_username
}

output "mail_from" {
  value = module.katachi.mail_from
}

output "smtp_app_client_id" {
  value = module.katachi.smtp_app_client_id
}

output "email_service_name" {
  value = module.katachi.email_service_name
}

output "postgres_server_name" {
  value = module.katachi.postgres_server_name
}

output "power_client_id" {
  value = module.katachi.power_client_id
}
