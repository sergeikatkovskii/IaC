# Env-root variables. `environment` is deliberately NOT one of them — it is fixed
# in main.tf, because the directory IS the environment. Passing it in would let a
# staging apply declare itself production.

variable "subscription_id" {
  type        = string
  description = "Subscription holding the storage account being watched."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the alert rules and the action group."
}

variable "location" {
  type        = string
  description = "Region for the alert rules and, if created here, the workspace."
  default     = "centralus"
}

variable "storage_account_id" {
  type        = string
  description = "Full resource id of the storage account holding tenant objects."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing workspace, or empty to have the module create one."
  default     = ""
}

variable "log_retention_days" {
  type        = number
  description = "Workspace retention, 30-90."
  default     = 30
}

variable "cluster_egress_cidrs" {
  type        = list(string)
  description = "The cluster's outbound addresses."
  default     = []
}

variable "office_vpn_cidrs" {
  type        = list(string)
  description = "Office / VPN ranges."
  default     = []
}

variable "enable_sas_egress_alert" {
  type        = bool
  description = "Off until KAT-417 T-005 relays downloads. See docs/runbooks/storage-alerts.md."
  default     = false
}

variable "alert_email_receivers" {
  type        = map(string)
  description = "name => email address."
  default     = {}
}

variable "alert_webhook_url" {
  type        = string
  description = "Support-channel webhook. Pass via TF_VAR_alert_webhook_url, never a committed file."
  default     = ""
  sensitive   = true
}

variable "skip_query_validation" {
  type        = bool
  description = "True on a first apply: StorageBlobLogs does not exist until the first log lands."
  default     = true
}
