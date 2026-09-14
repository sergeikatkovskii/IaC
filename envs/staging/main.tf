# Staging — KAT-417 T-004 storage detection.
#
# This root holds no resources of its own. It selects an environment's values and
# calls the shared module, so staging and production differ by tfvars rather than
# by configuration that has to be kept in sync by hand.

module "storage_detection" {
  source = "../../modules/storage-detection"

  environment         = "staging"
  resource_group_name = var.resource_group_name
  location            = var.location
  storage_account_id  = var.storage_account_id

  log_analytics_workspace_id = var.log_analytics_workspace_id
  log_retention_days         = var.log_retention_days

  cluster_egress_cidrs    = var.cluster_egress_cidrs
  office_vpn_cidrs        = var.office_vpn_cidrs
  enable_sas_egress_alert = var.enable_sas_egress_alert

  alert_email_receivers = var.alert_email_receivers
  alert_webhook_url     = var.alert_webhook_url

  skip_query_validation = var.skip_query_validation
}
