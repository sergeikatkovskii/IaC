# Staging values. Committed on purpose: names, regions and sizes, not secrets. The
# one secret here, alert_webhook_url, is passed as TF_VAR_alert_webhook_url.
#
# ⚠ Katachi has no Azure footprint yet. Each REPLACE below is the founder's answer
# still to come, and `terraform plan` refuses it until it is real — deliberately,
# because a placeholder that plans clean is how one gets applied by accident.
#   subscription_id      KAT-648 §8 Q1 (later)
#   app_host, mcp_host   KAT-648 §8 Q2 (staging.katachi.io and mcp.staging.katachi.io recommended, if the domain is his)
#   operator_ip_ranges   the address he runs Terraform and writes the vault's values from

subscription_id     = "REPLACE-WITH-SUBSCRIPTION-GUID"
location            = "centralus"
resource_group_name = "katachi-staging"

app_host      = "REPLACE-staging-app-host"
mcp_host      = "REPLACE-staging-mcp-host"
dns_zone_name = ""

operator_ip_ranges = ["REPLACE"]

# True only while first boot runs, then false and applied again (KAT-648 §8 Q10).
first_boot_open = false

# KAT-648 §8 Q3, recommended: Azure's managed PostgreSQL 15, at least B2s.
postgres_sku_name = "B_Standard_B2s"

cluster_sku_tier = "Free"
node_vm_size     = "Standard_D2as_v5"
node_min_count   = 2
node_max_count   = 3

log_retention_days = 30
log_daily_quota_gb = 1

# KAT-417's alerts, unchanged.
enable_sas_alert = true

alert_email_receivers = {
  oncall = "sergei.katkovskii@gmail.com"
}

skip_query_validation = true
