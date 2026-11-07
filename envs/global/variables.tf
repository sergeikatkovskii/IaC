variable "subscription_id" {
  type        = string
  description = "Subscription that holds the shared Terraform state account and the budget (KAT-648 §8 Q1)."

  validation {
    condition     = !can(regex("REPLACE", var.subscription_id))
    error_message = "subscription_id is still a placeholder: the founder gives the subscription (KAT-648 §8 Q1)."
  }

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id is a subscription GUID."
  }
}

variable "subscription_name" {
  type        = string
  description = "KAT-648 §8 Q1: this root is applied once in each subscription (AZ2-NonProd for staging, AZ1-TCM for production, as Azure names them), and the name is checked against the id given at run time."
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

variable "monthly_budget" {
  type        = number
  description = "The monthly ceiling, in the subscription's billing currency (KAT-648 §8 Q7)."

  validation {
    condition     = var.monthly_budget > 0
    error_message = "monthly_budget is the founder's ceiling (KAT-648 §8 Q7). 0 is the committed placeholder and is refused."
  }
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Who is mailed at 50, 80 and 100 per cent of actual spend, and at 100 per cent forecast."

  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "A budget that mails nobody is a budget nobody reads."
  }
}
