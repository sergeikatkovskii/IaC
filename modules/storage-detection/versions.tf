# A module declares which providers it needs and never configures one. The
# provider block (and the subscription it points at) belongs to the env root that
# calls this — otherwise the module could only ever be used against one
# subscription, and two envs could not differ.
terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12.0"
    }
  }
}
