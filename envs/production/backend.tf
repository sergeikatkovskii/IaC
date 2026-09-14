# State for THIS environment only. The key is what separates it from production —
# same account, same container, different blob, so one env's apply can never touch
# the other's state.
#
# A backend block cannot use variables, so these values are literal and must match
# what `envs/global` created. Run that first.
#
# `use_azuread_auth` keeps a storage account key out of this file and out of the
# shell that runs Terraform: it authenticates as your `az login` identity instead.
terraform {
  backend "azurerm" {
    resource_group_name  = "katachi-tfstate"
    storage_account_name = "katachitfstate"
    container_name       = "tfstate"
    key                  = "production/storage-detection.tfstate"
    use_azuread_auth     = true
  }
}
