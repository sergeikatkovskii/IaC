# KAT-648 — production. This root holds no resources of its own: it gives one
# environment's values to modules/environment, so production and staging differ by
# terraform.tfvars and never by an edited copy (ARD-059 §3).
#
# `environment` is fixed here rather than taken as a variable, because the
# directory IS the environment: a variable would let a production apply declare itself
# staging.

module "katachi" {
  source = "../../modules/environment"

  environment         = "production"
  subscription_name   = var.subscription_name
  location            = var.location
  resource_group_name = var.resource_group_name

  app_host           = var.app_host
  mcp_host           = var.mcp_host
  admin_host         = var.admin_host
  dns_zone_name      = var.dns_zone_name
  operator_ip_ranges = var.operator_ip_ranges

  first_boot_open = var.first_boot_open
  power_schedule  = var.power_schedule

  postgres_sku_name               = var.postgres_sku_name
  postgres_admin_password_version = var.postgres_admin_password_version

  kubernetes_version       = var.kubernetes_version
  cluster_sku_tier         = var.cluster_sku_tier
  node_vm_size             = var.node_vm_size
  node_min_count           = var.node_min_count
  node_max_count           = var.node_max_count
  cluster_admin_object_ids = var.cluster_admin_object_ids

  log_retention_days = var.log_retention_days
  log_daily_quota_gb = var.log_daily_quota_gb

  enable_sas_alert      = var.enable_sas_alert
  alert_email_receivers = var.alert_email_receivers
  alert_webhook_url     = var.alert_webhook_url
  skip_query_validation = var.skip_query_validation

  ai_capacity = var.ai_capacity
}
