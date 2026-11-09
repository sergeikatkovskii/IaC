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

# The founder's shape (2026-11-07): B1ms, whose 35 user connections production's
# overlay sizes its pools for (tcm k8s/overlays/production); B2s (414) when load asks.
postgres_sku_name = "B_Standard_B1ms"

# The founder's shape (2026-11-07, "two reserved node"): two Standard_D2as_v5, which he
# reserves for a year in the portal (37.00 USD a node a month against 70.96), and no
# third the reservation would not cover. The minor staging and the pipeline run.
kubernetes_version = "1.35"
cluster_sku_tier   = "Free"
node_vm_size       = "Standard_D2as_v5"
node_min_count     = 2
node_max_count     = 2

# 90 rather than staging's 30: an incident here is the one investigated weeks later.
log_retention_days = 90
# Ingestion stops for the day at 0.3 GB: at most about 25 USD a month.
log_daily_quota_gb = 0.3

enable_sas_alert = true

alert_email_receivers = {
  oncall = "sergei.katkovskii@gmail.com"
}

skip_query_validation = true

# KAT-650 T-001: the plan's AI, gpt-6-luna on Global Standard (the founder's
# answers, 2026-11-08), at 250 thousand tokens a minute: the subscription's whole
# Tier 1 pool for gpt-6-luna.
# Microsoft's quota tier decides whether it can be deployed at all; the runbook
# reads it first (docs/runbooks/staging.md in tcm).
ai_capacity = 250
