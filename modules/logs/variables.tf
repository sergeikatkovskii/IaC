variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "retention_in_days" {
  type        = number
  description = "Sized to answer an incident, not an auditor."
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  type        = number
  description = "Ingestion stops for the day at this many GB. Azure's -1 means no cap, which is refused: a noisy component is a bill nobody sees coming."
  default     = 1

  validation {
    condition     = var.daily_quota_gb > 0
    error_message = "daily_quota_gb must be a positive cap; -1 (no cap) is refused."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
