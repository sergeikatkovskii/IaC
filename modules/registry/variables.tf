variable "name" {
  type        = string
  description = "Globally unique, 5-50 letters and digits."

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.name))
    error_message = "A registry name is 5-50 letters and digits."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  type        = string
  description = "Basic is enough for staging. Network rules and private endpoints need Premium."
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard or Premium."
  }
}

variable "pull_principal_ids" {
  type        = map(string)
  description = "name => principal id that may pull. The cluster's kubelet identity."
  default     = {}
}

variable "push_principal_ids" {
  type        = map(string)
  description = "name => principal id that may push. The pipeline, and nothing else."
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
