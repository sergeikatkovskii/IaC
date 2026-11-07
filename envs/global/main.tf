# Shared, environment-independent infrastructure: the Terraform state backend the
# other roots use. Nothing that belongs to a single environment goes here.

# KAT-648 T-005: the subscription the provider was pointed at, checked by its name.
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "shared" {
  name     = var.resource_group_name
  location = var.location

  lifecycle {
    precondition {
      condition     = data.azurerm_subscription.current.display_name == var.subscription_name
      error_message = "The provider is pointed at the subscription \"${data.azurerm_subscription.current.display_name}\", and these values are for \"${var.subscription_name}\". Nothing was planned."
    }
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                = var.state_account_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  account_tier             = "Standard"
  account_replication_type = "GRS"

  # State is the most sensitive thing in this repo: it holds resource ids and can
  # hold secrets in plaintext. None of these three is optional.
  allow_nested_items_to_be_public = false
  public_network_access           = "Enabled" # tighten to a private endpoint when a VNet exists
  min_tls_version                 = "TLS1_2"  # the highest minimum Azure Storage takes; clients negotiate 1.3
  # KAT-648 T-005: the backends sign in with Entra (use_azuread_auth), so no key is
  # needed, and with the keys off none can be used.
  shared_access_key_enabled = false
  # KAT-648 T-005, from trivy config: encrypted at the infrastructure layer as well
  # (settable only when the account is made), and answering only the operator's
  # address. Terraform manages the container through Azure Resource Manager, which
  # these rules do not govern; the backends read the state from his address.
  infrastructure_encryption_enabled = true

  network_rules {
    default_action = "Deny"
    ip_rules       = var.operator_ip_ranges
    bypass         = ["AzureServices"]
  }

  # Terraform's own locking protects against two concurrent applies; versioning is
  # what protects against a corrupted or truncated state being written over a good
  # one, which locking cannot help with.
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }
}

# KAT-648 T-005: whoever applies this root reads and writes the state's blobs with
# their own sign-in. Owning the subscription grants no right to an account's data.
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "state_writer" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
