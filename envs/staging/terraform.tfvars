# Staging values. Committed on purpose: names, regions and sizes, not secrets. The
# one secret here, alert_webhook_url, is passed as TF_VAR_alert_webhook_url.
#
# ⚠ This repository is PUBLIC. Two values are never committed, and stay REPLACE here,
# refused by `terraform plan` until they are given: they come from
# envs/staging/staging.local.tfvars, which .gitignore keeps on the founder's machine
# (docs/runbooks/staging.md in tcm writes it):
#   subscription_id      read from Azure by the subscription's name (AZ2-NonProd, as
#                        Azure names it; az's cache may say AZ2), never typed;
#                        subscription_name below is checked against it
#   operator_ip_ranges   the address he runs Terraform and writes the vault's values from,
#                        as a bare IP: Azure Storage refuses a /31 or /32 range
#
# KAT-648 §8 Q2, answered 2026-11-06: staging.katachi.io, mcp.staging.katachi.io and
# admin.staging.katachi.io, in a zone of their own, staging.katachi.io, which the
# founder delegates from GoDaddy once, with four NS records, after the first apply
# (terraform output dns_name_servers). ansible/inventories/staging holds the same three.

subscription_id     = "REPLACE-WITH-SUBSCRIPTION-GUID"
subscription_name   = "AZ2-NonProd"
location            = "centralus"
resource_group_name = "katachi-staging"

app_host      = "staging.katachi.io"
mcp_host      = "mcp.staging.katachi.io"
admin_host    = "admin.staging.katachi.io"
dns_zone_name = "staging.katachi.io"

operator_ip_ranges = ["REPLACE"]

# True only while first boot runs, then false and applied again (KAT-648 §8 Q10).
first_boot_open = false

# KAT-648 §8 Q3, recommended: Azure's managed PostgreSQL 15, at least B2s.
postgres_sku_name = "B_Standard_B2s"

# The minor minikube's kat648 profile proved the manifests on (1.35.1) and the
# pipeline's kubectl matches; AKS keeps the patch current (KAT-648 T-005).
kubernetes_version = "1.35"
cluster_sku_tier   = "Free"
node_vm_size       = "Standard_D2as_v5"
node_min_count     = 2
node_max_count     = 3

log_retention_days = 30
log_daily_quota_gb = 1

# KAT-417's alerts, unchanged.
enable_sas_alert = true

alert_email_receivers = {
  oncall = "sergei.katkovskii@gmail.com"
}

skip_query_validation = true
