variable "subscription_id" {
  type        = string
  description = "Subscription that holds the shared Terraform state account."
}

variable "location" {
  type        = string
  description = "Region for the state account."
  default     = "centralus"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for shared, environment-independent infrastructure."
  default     = "katachi-tfstate"
}

variable "state_account_name" {
  type        = string
  description = <<-EOT
    Storage account for Terraform state. Globally unique across all of Azure,
    3-24 chars, lowercase letters and digits only.
  EOT

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_account_name))
    error_message = "state_account_name must be 3-24 lowercase letters and digits."
  }
}
