# The rendered queries, so the fire drill in docs/runbooks/storage-alerts.md pastes
# the EXACT text the rule evaluates rather than a version of it that was retyped.
#
#   terraform output -raw query_sas_used

output "query_anonymous_success" {
  value       = local.query_anonymous_success
  description = "Alert 1's query, as evaluated."
}

output "query_container_list" {
  value       = local.query_container_list
  description = "Alert 2's query, as evaluated."
}

output "query_sas_used" {
  value       = local.query_sas_used
  description = "Alert 3's query, as evaluated."
}

output "workspace_id" {
  value       = local.workspace_id
  description = "Workspace the storage logs land in — the one to query during an incident."
}

output "sas_alert_enabled" {
  value       = var.enable_sas_alert
  description = "Alert 3 (any SAS used). On since KAT-417 T-005. See the runbook."
}
