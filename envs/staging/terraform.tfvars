# Staging values. Committed on purpose: these are resource ids, regions and CIDRs,
# not secrets. The one secret this module takes — alert_webhook_url — is passed as
# TF_VAR_alert_webhook_url and must never appear here.
#
# ⚠ Katachi has no Azure footprint yet, so the two ids below are PLACEHOLDERS.
# `terraform plan` will refuse them with a clear message until they are real; that
# refusal is deliberate and is better than a default that would apply.

subscription_id     = "REPLACE-WITH-SUBSCRIPTION-GUID"
resource_group_name = "katachi-staging"
location            = "centralus"

# Full account id, no /blobServices suffix — the module appends it.
storage_account_id = "/subscriptions/REPLACE/resourceGroups/katachi-staging/providers/Microsoft.Storage/storageAccounts/REPLACE"

# Empty => the module creates katachi-storage-staging.
log_analytics_workspace_id = ""
log_retention_days         = 30

# Alert 3: any SAS-authenticated request that succeeds. ON since KAT-417 T-005 —
# the product relays every download and mints no storage credential at all.
enable_sas_alert = true

alert_email_receivers = {
  oncall = "sergei.katkovskii@gmail.com"
}

# True on a first apply — StorageBlobLogs does not exist until the first log lands.
skip_query_validation = true
