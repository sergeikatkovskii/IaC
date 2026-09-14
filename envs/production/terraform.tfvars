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

# Alert 3: any SAS-authenticated request that succeeds. ON since KAT-417 T-005 —
# the product relays every download and mints no storage credential at all, so a
# SAS existing is a fact about a human, a leaked key or a second system. It took
# no CIDR list with it: the egress carve-out existed to excuse customer downloads,
# and there are none to excuse.
enable_sas_alert = true

alert_email_receivers = {
  oncall = "sergei.katkovskii@gmail.com"
}

skip_query_validation = true
