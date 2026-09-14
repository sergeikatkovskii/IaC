# ── Where ──────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  type        = string
  description = "Resource group for the alert rules and the action group."
}

variable "location" {
  type        = string
  description = "Azure region for the alert rules and, if created here, the workspace."
  default     = "centralus"
}

variable "environment" {
  type        = string
  description = <<-EOT
    Environment name, used to suffix every resource. Matches KAT-S10's ENVIRONMENT
    switch: the dev AKS cluster is `staging`, not `production`.
  EOT

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production (KAT-S10)."
  }
}

# ── What is watched ────────────────────────────────────────────────────────────

variable "storage_account_id" {
  type        = string
  description = <<-EOT
    Full resource id of the storage account holding tenant objects. The diagnostic
    setting is attached to its **blob service**, not to the account: StorageRead /
    StorageWrite / StorageDelete are categories of `<account>/blobServices/default`,
    and an account-level setting silently offers only Transaction/Capacity metrics.
  EOT

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft[.]Storage/storageAccounts/[^/]+$", var.storage_account_id))
    error_message = "storage_account_id must be a full storage account resource id, with no /blobServices suffix — the module appends it."
  }

  validation {
    # KAT-S10's lesson, applied here: a placeholder that merely *looks* like a real
    # value passes a shape check. `.../storageAccounts/REPLACE` is a well-formed
    # resource id, so the regex above accepts it and the whole thing plans clean —
    # which is how a committed tfvars full of placeholders gets applied by accident.
    # The marker is matched as a whole segment so a real account called
    # "replaceable" still passes.
    condition     = !can(regex("(^|[/_-])REPLACE([/_-]|$)", var.storage_account_id))
    error_message = "storage_account_id still contains a REPLACE placeholder — fill in the real account id before applying."
  }
}

# ── Where the logs land ────────────────────────────────────────────────────────

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing workspace to send logs to. Leave empty to have this module create one."
  default     = ""
}

variable "log_retention_days" {
  type        = number
  description = <<-EOT
    Retention for the workspace this module creates. Sized to answer an incident,
    not an auditor — see docs/runbooks/storage-alerts.md on volume.
  EOT
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 90
    error_message = "log_retention_days must be between 30 and 90."
  }
}

# ── Alert 3's egress ranges ────────────────────────────────────────────────────

variable "cluster_egress_cidrs" {
  type        = list(string)
  description = "The AKS cluster's outbound addresses — the only place a SAS should legitimately be presented from."
  default     = []
}

variable "office_vpn_cidrs" {
  type        = list(string)
  description = "Office / VPN ranges, for an operator working through a jump host."
  default     = []
}

variable "enable_sas_egress_alert" {
  type        = bool
  description = <<-EOT
    Alert 3 is OFF by default and this is deliberate. Until KAT-417 T-005 relays
    downloads through the API, every customer clicking their own download link
    presents a SAS from their own address, so the rule's common case is benign and
    it would be muted within a day. Turn it on when T-005 ships.
  EOT
  default     = false
}

variable "skip_query_validation" {
  type        = bool
  description = <<-EOT
    Azure validates an alert rule's KQL against the workspace schema at create time,
    and `StorageBlobLogs` does not exist until the first log actually lands — which
    is minutes after the diagnostic setting is created, and in the same apply. So a
    FIRST apply with validation on fails on a correct configuration, which is why
    this defaults to true.

    The cost is real: a typo in a query is then not caught at apply time, and a rule
    that cannot parse is indistinguishable from a rule with nothing to report. The
    fire drill in docs/runbooks/storage-alerts.md is what covers that gap — pasting
    each query into Log Analytics once data exists IS the validation. Flip this to
    false on a later apply, once the table exists, to get it from Azure as well.
  EOT
  default     = true
}

# ── Who is told ────────────────────────────────────────────────────────────────

variable "alert_email_receivers" {
  type        = map(string)
  description = "name => email address. Routed to the same on-call as KAT-211."
  default     = {}
}

variable "alert_webhook_url" {
  type        = string
  description = "Support-channel webhook. Real value belongs in the secret store, never in a committed tfvars."
  default     = ""
  sensitive   = true
}
