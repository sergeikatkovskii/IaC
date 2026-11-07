# KAT-648 T-005 — tenant files, in KAT-417's shape (ARD-039).
mock_provider "azurerm" {
  # KAT-418 T-003: the account's id and blob address, and the role's id, are Azure's to
  # give. They are given at plan, so the role's scope and the address can be read, and
  # shaped as Azure's, because the provider still validates what a mock answers.
  mock_resource "azurerm_storage_account" {
    override_during = plan
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Storage/storageAccounts/katachitestdata01"
      primary_blob_endpoint = "https://katachitestdata01.blob.core.windows.net/"
    }
  }

  mock_resource "azurerm_role_definition" {
    override_during = plan
    defaults = {
      role_definition_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-0000-0000-0000-000000000001"
    }
  }
}

variables {
  name                = "katachitestdata01"
  resource_group_name = "katachi-test"
  resource_group_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test"
  location            = "centralus"
  allowed_subnet_ids  = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks"]
  operator_ip_ranges  = ["203.0.113.7"]
}

run "nothing_is_public" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.allow_nested_items_to_be_public == false && azurerm_storage_container.attachments.container_access_type == "private"
    error_message = "No container and no blob can be made public (ARD-039 §4)."
  }

  assert {
    condition     = azurerm_storage_account.this.network_rules[0].default_action == "Deny"
    error_message = "The account answers only the cluster's subnet and the operator's addresses."
  }
}

run "https_only_and_encrypted_twice" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.https_traffic_only_enabled && azurerm_storage_account.this.infrastructure_encryption_enabled
    error_message = "HTTPS only, and a second layer of encryption at rest."
  }

  assert {
    condition     = azurerm_storage_account.this.cross_tenant_replication_enabled == false
    error_message = "Nothing copies these objects to another tenant."
  }
}

run "a_delete_can_be_undone_for_a_week" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.blob_properties[0].versioning_enabled && azurerm_storage_account.this.blob_properties[0].delete_retention_policy[0].days == 7
    error_message = "Versioning, and a week to undo a delete."
  }
}

run "the_container_is_the_products" {
  command = plan

  assert {
    condition     = azurerm_storage_container.attachments.name == "tcm-attachments"
    error_message = "AZURE_STORAGE_CONTAINER_NAME defaults to tcm-attachments in backend/app/core/config.py."
  }
}

run "a_placeholder_address_is_refused" {
  command = plan

  variables {
    operator_ip_ranges = ["REPLACE"]
  }

  expect_failures = [var.operator_ip_ranges]
}

# KAT-418 T-003 (feature §8 Q6, the founder's "Recommendation accepted", 2026-11-07):
# the one role the units hold on storage, written to what the code calls. The boot
# preflight reads the container's properties; every other call reads, writes or
# deletes a blob (tcm app/services/blob_storage_service.py). Storage Blob Data
# Contributor would also create and delete containers, move and append blobs, and
# make user-delegation keys. The product does none of it, and a stolen pod token
# could otherwise delete the whole container.
run "the_role_moves_bytes_and_nothing_else" {
  command = plan

  assert {
    condition     = length(azurerm_role_definition.blob_data.permissions) == 1
    error_message = "One permissions block, so the sets below are the whole role."
  }

  assert {
    condition     = toset(azurerm_role_definition.blob_data.permissions[0].actions) == toset(["Microsoft.Storage/storageAccounts/blobServices/containers/read"])
    error_message = "One control action: reading the container's properties (the preflight's exists and not public). No container is made or deleted, and no delegation key."
  }

  assert {
    condition = toset(azurerm_role_definition.blob_data.permissions[0].data_actions) == toset([
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
    ])
    error_message = "Read, write and delete a blob, which is what upload, the block upload, the relay and delete call, and nothing else."
  }

  assert {
    condition     = length(azurerm_role_definition.blob_data.permissions[0].not_actions) == 0 && length(azurerm_role_definition.blob_data.permissions[0].not_data_actions) == 0
    error_message = "The role names what it allows; nothing is granted and then carved out."
  }

  assert {
    condition     = azurerm_role_definition.blob_data.name == "katachitestdata01-blob-data"
    error_message = "A custom role's name is unique in the directory, which staging and production share: it is named for its account, whose name is unique across Azure."
  }
}

run "each_unit_given_holds_it_on_the_container_alone" {
  command = plan

  variables {
    data_principal_ids = {
      backend = "aaaaaaaa-0000-0000-0000-000000000001"
      mcp     = "aaaaaaaa-0000-0000-0000-000000000002"
    }
  }

  assert {
    condition     = length(azurerm_role_assignment.blob_data) == 2 && azurerm_role_assignment.blob_data["backend"].principal_id == "aaaaaaaa-0000-0000-0000-000000000001" && azurerm_role_assignment.blob_data["mcp"].principal_id == "aaaaaaaa-0000-0000-0000-000000000002"
    error_message = "Each unit given holds the role once, as itself."
  }

  assert {
    condition     = alltrue([for a in values(azurerm_role_assignment.blob_data) : a.scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Storage/storageAccounts/katachitestdata01/blobServices/default/containers/tcm-attachments"])
    error_message = "The role is held on the product's container, never on the account, the resource group or wider, so a unit reaches no other container."
  }

  assert {
    condition     = alltrue([for a in values(azurerm_role_assignment.blob_data) : a.role_definition_id == azurerm_role_definition.blob_data.role_definition_resource_id && a.principal_type == "ServicePrincipal"])
    error_message = "What a unit holds is this role, never a built-in one, given to its managed identity."
  }

  assert {
    condition     = output.container_scope == azurerm_role_assignment.blob_data["backend"].scope
    error_message = "container_scope is where the role is held: T-005's revocation runbook removes an assignment at exactly this scope."
  }

  assert {
    condition     = toset(output.holder_names) == toset(["backend", "mcp"])
    error_message = "The holders come out by name, for the environment's test."
  }
}

run "no_unit_no_role" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.blob_data) == 0 && length(output.holder_names) == 0
    error_message = "With no unit given, nothing holds the role."
  }
}

run "the_role_can_be_given_only_in_this_resource_group" {
  command = plan

  assert {
    condition     = toset(azurerm_role_definition.blob_data.assignable_scopes) == toset([var.resource_group_id]) && azurerm_role_definition.blob_data.scope == var.resource_group_id
    error_message = "The role can be given only inside this environment's resource group."
  }
}

run "the_address_is_the_accounts_blob_endpoint" {
  command = plan

  assert {
    condition     = output.blob_endpoint == azurerm_storage_account.this.primary_blob_endpoint
    error_message = "STORAGE_ACCOUNT_URL is the account's blob endpoint, where T-004's units reach storage as themselves."
  }
}
