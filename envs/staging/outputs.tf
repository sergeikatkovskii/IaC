output "workspace_id" {
  value       = module.storage_detection.workspace_id
  description = "Workspace the storage logs land in — the one to query during an incident."
}

output "sas_alert_enabled" {
  value       = module.storage_detection.sas_alert_enabled
  description = "False until KAT-417 T-005 relays downloads."
}

# The rendered queries, so the fire drill in docs/runbooks/storage-alerts.md pastes
# the exact text the rule evaluates:  terraform output -raw query_sas_outside_egress
output "query_anonymous_success" {
  value       = module.storage_detection.query_anonymous_success
  description = "Alert 1's query, as evaluated."
}

output "query_container_list" {
  value       = module.storage_detection.query_container_list
  description = "Alert 2's query, as evaluated."
}

output "query_sas_outside_egress" {
  value       = module.storage_detection.query_sas_outside_egress
  description = "Alert 3's query, as evaluated, with the egress ranges substituted."
}
