# KAT-648 T-005 — staging is turned off on a schedule and on demand (the founder,
# 2026-11-07). The scheduled job runs unattended, so it cannot wait for his approval
# as a release does; what it signs in as may therefore do one thing: read, start and
# stop staging's cluster and database server, and nothing else anywhere.
mock_provider "azurerm" {
  mock_resource "azurerm_role_definition" {
    override_during = plan
    defaults = {
      role_definition_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-0000-0000-0000-000000000001"
    }
  }
}

variables {
  name_prefix         = "katachi-test"
  resource_group_name = "katachi-test"
  resource_group_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test"
  location            = "centralus"
  cluster_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.ContainerService/managedClusters/aks"
  server_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/pg"
  github_repository   = "sergeikatkovskii/tcm"
  github_environment  = "staging"
}

run "the_role_reads_starts_and_stops_and_does_nothing_else" {
  command = plan

  assert {
    condition = toset(azurerm_role_definition.power.permissions[0].actions) == toset([
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/start/action",
      "Microsoft.ContainerService/managedClusters/stop/action",
      "Microsoft.DBforPostgreSQL/flexibleServers/read",
      "Microsoft.DBforPostgreSQL/flexibleServers/start/action",
      "Microsoft.DBforPostgreSQL/flexibleServers/stop/action",
    ])
    error_message = "Read, start and stop, on a cluster and a database server: nothing that changes, reads a secret or reaches inside."
  }

  assert {
    condition     = length(azurerm_role_definition.power.permissions[0].data_actions) == 0 && length(azurerm_role_definition.power.permissions[0].not_actions) == 0
    error_message = "No data action: it never reaches inside the cluster or the database."
  }
}

run "it_holds_that_role_on_the_two_resources_alone" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.cluster.scope == var.cluster_id && azurerm_role_assignment.server.scope == var.server_id
    error_message = "The role is held on staging's cluster and its database server, and nowhere else."
  }

  assert {
    condition     = toset(azurerm_role_definition.power.assignable_scopes) == toset([var.resource_group_id])
    error_message = "The role can be given only inside staging's resource group."
  }
}

run "only_a_job_in_its_own_environment_signs_in_as_it" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.power.subject == "repo:sergeikatkovskii/tcm:environment:staging-power" && azurerm_federated_identity_credential.power.issuer == "https://token.actions.githubusercontent.com"
    error_message = "Only a GitHub job in the environment staging-power, which a release can never use, signs in as the power identity."
  }
}
