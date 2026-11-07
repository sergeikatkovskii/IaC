# KAT-648 T-005 — tenant files, in KAT-417's shape (ARD-039): one private container,
# every object under its tenant's prefix, nothing public, and the account answering
# only the cluster's subnet. storage-detection watches it.

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.replication_type
  access_tier              = "Hot"

  https_traffic_only_enabled = true
  # TLS1_2 is the only value Azure Storage accepts as a floor. The product's own
  # client refuses anything below TLS 1.3 (app/core/tls.py, ARD-043).
  min_tls_version = "TLS1_2"

  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = true

  # The product reads a connection string from the vault until KAT-418 replaces it
  # with a workload identity (ARD-040; KAT-648 §2 and §8 Q8). Then this goes false.
  shared_access_key_enabled = true

  public_network_access = "Enabled"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["None"]
    ip_rules                   = var.operator_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.delete_retention_days
    }

    container_delete_retention_policy {
      days = var.delete_retention_days
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "attachments" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# KAT-418 T-003 (feature §8 Q6, the founder's answer of 2026-11-07): the one role the
# units hold on storage, and only what the code calls. The boot preflight reads the
# container's properties (it exists, and is not public); every other call reads,
# writes or deletes a blob. The built-in Storage Blob Data Contributor would also
# create and delete containers, move and append blobs and make user-delegation keys.
# The product does none of it, and with that role a stolen pod token could delete the
# whole container. The role is held on the container, never on the account: making a
# delegation key is an account-level act, so after T-005 no unit can make a SAS.
locals {
  # Built from the account and the container's name rather than from the container's
  # id, whose shape is the provider's to choose. Naming the container also orders each
  # assignment after it.
  container_scope = "${azurerm_storage_account.this.id}/blobServices/default/containers/${azurerm_storage_container.attachments.name}"
}

resource "azurerm_role_definition" "blob_data" {
  name        = "${var.name}-blob-data"
  scope       = var.resource_group_id
  description = "Read the container's properties, and read, write and delete its blobs, and nothing else (KAT-418)."

  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
    ]
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
    ]
    not_actions      = []
    not_data_actions = []
  }

  assignable_scopes = [var.resource_group_id]
}

resource "azurerm_role_assignment" "blob_data" {
  for_each = var.data_principal_ids

  scope              = local.container_scope
  role_definition_id = azurerm_role_definition.blob_data.role_definition_resource_id
  principal_id       = each.value
  principal_type     = "ServicePrincipal"
}
