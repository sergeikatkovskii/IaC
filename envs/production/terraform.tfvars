# Production values. Committed on purpose: names, regions and sizes, not secrets.
# alert_webhook_url is passed as TF_VAR_alert_webhook_url.
#
# ⚠ Production is the founder's call once he has seen staging (KAT-648 §2). Every
# REPLACE is refused by `terraform plan`, and the sizes below are staging's until
# the production cutover decides them.

subscription_id     = "REPLACE-WITH-SUBSCRIPTION-GUID"
subscription_name   = "AZ1-TCM"
location            = "centralus"
resource_group_name = "katachi-production"

app_host      = "REPLACE-production-app-host"
mcp_host      = "REPLACE-production-mcp-host"
admin_host    = "REPLACE-production-admin-host"
dns_zone_name = ""

operator_ip_ranges = ["REPLACE"]

first_boot_open = false

postgres_sku_name = "B_Standard_B2s"

cluster_sku_tier = "Free"
node_vm_size     = "Standard_D2as_v5"
node_min_count   = 2
node_max_count   = 3

# 90 rather than staging's 30: an incident here is the one investigated weeks later.
log_retention_days = 90
log_daily_quota_gb = 1

enable_sas_alert = true

alert_email_receivers = {
  oncall = "sergei.katkovskii@gmail.com"
}

skip_query_validation = true
