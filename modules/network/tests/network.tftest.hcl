# KAT-648 T-005 — the network. Asserts only what the configuration states, so a
# mocked provider can answer it with no subscription.
mock_provider "azurerm" {}

variables {
  name_prefix         = "katachi-test"
  resource_group_name = "katachi-test"
  location            = "centralus"
}

run "the_database_subnet_is_delegated_to_postgres_only" {
  command = plan

  assert {
    condition     = length(azurerm_subnet.postgres.delegation) == 1 && azurerm_subnet.postgres.delegation[0].service_delegation[0].name == "Microsoft.DBforPostgreSQL/flexibleServers"
    error_message = "The database subnet must be delegated to PostgreSQL Flexible Server and to nothing else."
  }
}

run "the_node_subnet_reaches_the_vault_and_storage_by_service_endpoint" {
  command = plan

  assert {
    condition     = toset([for e in azurerm_subnet.aks.service_endpoint : e.service]) == toset(["Microsoft.KeyVault", "Microsoft.Storage"])
    error_message = "The node subnet needs exactly the Key Vault and Storage service endpoints: both are default-deny and admit this subnet."
  }
}

run "the_database_name_resolves_privately" {
  command = plan

  assert {
    condition     = endswith(azurerm_private_dns_zone.postgres.name, ".private.postgres.database.azure.com")
    error_message = "A Flexible Server with private access needs a private zone ending in .private.postgres.database.azure.com."
  }

  assert {
    condition     = azurerm_private_dns_zone_virtual_network_link.postgres.registration_enabled == false
    error_message = "Nothing should register itself into the database's zone."
  }
}
