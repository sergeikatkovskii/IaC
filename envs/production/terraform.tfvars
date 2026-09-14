# Production values. Committed on purpose: resource ids, regions and CIDRs, not
# secrets. alert_webhook_url is passed as TF_VAR_alert_webhook_url and must never
# appear here.
#
# ⚠ Katachi has no Azure footprint yet, so the two ids below are PLACEHOLDERS.
# `terraform plan` will refuse them until they are real.

subscription_id     = "REPLACE-WITH-SUBSCRIPTION-GUID"
resource_group_name = "katachi-production"
location            = "centralus"

storage_account_id = "/subscriptions/REPLACE/resourceGroups/katachi-production/providers/Microsoft.Storage/storageAccounts/REPLACE"

log_analytics_workspace_id = ""

# 90 rather than staging's 30: an incident here is the one that gets investigated
# weeks later. Still sized to answer an incident, not an auditor.
log_retention_days = 90

# Alert 3 stays off until KAT-417 T-005 relays downloads through the API. When it
# lands, set this true AND fill cluster_egress_cidrs — the module refuses the
# combination of "enabled" with no ranges, because that is a pager that never stops.
enable_sas_egress_alert = false
cluster_egress_cidrs    = []
office_vpn_cidrs        = []

alert_email_receivers = {
  oncall = "sergei.katkovskii@gmail.com"
}

skip_query_validation = true
