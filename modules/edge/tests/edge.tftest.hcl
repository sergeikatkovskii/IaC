# KAT-648 T-005 — the public address the gateway answers on.
mock_provider "azurerm" {}

variables {
  name                 = "katachi-test-gateway"
  resource_group_name  = "katachi-test"
  location             = "centralus"
  app_host             = "staging.example.test"
  mcp_host             = "mcp.staging.example.test"
  admin_host           = "admin.staging.example.test"
  cluster_principal_id = "44444444-4444-4444-4444-444444444444"
}

run "the_address_is_static" {
  command = plan

  assert {
    condition     = azurerm_public_ip.gateway.allocation_method == "Static" && azurerm_public_ip.gateway.sku == "Standard"
    error_message = "A static Standard address, so DNS never points at somebody else's machine."
  }

  assert {
    condition     = azurerm_role_assignment.cluster_network.role_definition_name == "Network Contributor" && azurerm_role_assignment.cluster_network.principal_id == "44444444-4444-4444-4444-444444444444"
    error_message = "The cluster may attach its load balancer to this address."
  }
}

run "no_zone_until_one_is_named" {
  command = plan

  assert {
    condition     = length(azurerm_dns_zone.this) == 0 && length(azurerm_dns_a_record.host) == 0
    error_message = "With no zone named (KAT-648 §8 Q2 open), nothing is created in DNS."
  }
}

run "a_named_zone_gets_every_host" {
  command = plan

  variables {
    dns_zone_name = "example.test"
  }

  assert {
    condition     = length(azurerm_dns_zone.this) == 1 && toset([for r in azurerm_dns_a_record.host : r.name]) == toset(["staging", "mcp.staging", "admin.staging"])
    error_message = "The app, the MCP host and the operator console (KAT-648 §8 Q2) each get an alias record in the named zone."
  }
}

run "a_host_outside_the_zone_is_refused" {
  command = plan

  variables {
    dns_zone_name = "example.test"
    app_host      = "staging.other.test"
  }

  expect_failures = [var.app_host]
}

run "an_admin_host_outside_the_zone_is_refused" {
  command = plan

  variables {
    dns_zone_name = "example.test"
    admin_host    = "admin.other.test"
  }

  expect_failures = [var.admin_host]
}

run "a_placeholder_admin_host_is_refused" {
  command = plan

  variables {
    admin_host = "REPLACE-staging-admin-host"
  }

  expect_failures = [var.admin_host]
}
