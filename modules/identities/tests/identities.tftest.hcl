# KAT-648 T-005 — who signs in as what.
mock_provider "azurerm" {}

variables {
  name_prefix         = "katachi-test"
  resource_group_name = "katachi-test"
  location            = "centralus"
  oidc_issuer_url     = "https://oidc.example.test/tenant/cluster/"
  cluster_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.ContainerService/managedClusters/aks"
  github_repository   = "sergeikatkovskii/tcm"
  github_environment  = "staging"
}

run "each_unit_is_federated_to_exactly_its_own_service_account" {
  command = plan

  assert {
    condition     = length(azurerm_federated_identity_credential.unit) == 6 && alltrue([for u, c in azurerm_federated_identity_credential.unit : c.subject == "system:serviceaccount:tcm-system:${u}"])
    error_message = "backend, worker, scheduler, mcp, migrate and redis each sign in as their own service account in tcm-system, and nothing else."
  }

  assert {
    condition     = alltrue([for c in azurerm_federated_identity_credential.unit : length(c.audience) == 1 && c.audience[0] == "api://AzureADTokenExchange" && c.issuer == "https://oidc.example.test/tenant/cluster/"])
    error_message = "Each credential trusts only this cluster's issuer, for the token-exchange audience."
  }
}

run "first_boot_closed_means_the_bootstrap_cannot_sign_in" {
  command = plan

  assert {
    condition     = length(azurerm_federated_identity_credential.db_bootstrap) == 0
    error_message = "Anything that can start a pod in tcm-system can start it as db-bootstrap, which can read the administrator's password. Its sign-in exists only while first boot is open."
  }
}

run "first_boot_open_lets_the_bootstrap_sign_in" {
  command = plan

  variables {
    first_boot_open = true
  }

  assert {
    condition     = length(azurerm_federated_identity_credential.db_bootstrap) == 1 && azurerm_federated_identity_credential.db_bootstrap[0].subject == "system:serviceaccount:tcm-system:db-bootstrap"
    error_message = "During first boot, db-bootstrap signs in as its own service account."
  }
}

run "the_pipeline_signs_in_only_from_its_environment" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.pipeline.subject == "repo:sergeikatkovskii/tcm:environment:staging" && azurerm_federated_identity_credential.pipeline.issuer == "https://token.actions.githubusercontent.com"
    error_message = "Only a GitHub job in the repository's staging environment, which needs the founder's approval, signs in as the pipeline."
  }
}

run "the_pipeline_writes_only_in_its_namespace" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.pipeline_writer.role_definition_name == "Azure Kubernetes Service RBAC Writer" && azurerm_role_assignment.pipeline_writer.scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.ContainerService/managedClusters/aks/namespaces/tcm-system"
    error_message = "The pipeline writes in tcm-system and nowhere else."
  }

  assert {
    condition     = azurerm_role_assignment.pipeline_cluster_user.role_definition_name == "Azure Kubernetes Service Cluster User Role" && azurerm_role_assignment.pipeline_cluster_user.scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.ContainerService/managedClusters/aks"
    error_message = "At cluster scope the pipeline may only fetch its sign-in configuration."
  }
}

run "every_identity_has_a_client_id_out" {
  command = plan

  assert {
    condition     = toset(keys(output.unit_client_ids)) == toset(["backend", "worker", "scheduler", "mcp", "migrate", "redis", "db-bootstrap"])
    error_message = "Each unit, and db-bootstrap, has an identity whose client id reaches the overlay; KAT-648 T-003 added migrate and redis, which read the vault too."
  }
}
