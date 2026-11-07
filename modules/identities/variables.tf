variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "oidc_issuer_url" {
  type        = string
  description = "The cluster's OIDC issuer, which signs each service account's token."
}

variable "cluster_id" {
  type = string
}

variable "namespace" {
  type    = string
  default = "tcm-system"
}

variable "units" {
  type        = list(string)
  description = "The units that read the vault, each as its own service account. migrate and redis since KAT-648 T-003: the migration Job and Redis read their secrets through the CSI driver as themselves."
  default     = ["backend", "worker", "scheduler", "mcp", "migrate", "redis"]
}

variable "first_boot_open" {
  type        = bool
  description = <<-EOT
    True only while first boot runs. Anything that can start a pod in the namespace
    can start it as any ServiceAccount there, and db-bootstrap's identity reads the
    database administrator's password. Its sign-in therefore exists only while this
    is true (KAT-648 §8 Q10).
  EOT
  default     = false
}

variable "github_repository" {
  type    = string
  default = "sergeikatkovskii/tcm"
}

variable "github_environment" {
  type        = string
  description = "The GitHub environment whose jobs sign in as the pipeline; the founder is its required reviewer (KAT-648 §8 Q12)."

  validation {
    condition     = contains(["staging", "production"], var.github_environment)
    error_message = "github_environment must be staging or production."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
