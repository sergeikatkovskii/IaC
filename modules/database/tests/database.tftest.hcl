# KAT-648 T-005 — the database. `random` is not mocked: the ephemeral password is
# made locally and never leaves the run.
mock_provider "azurerm" {}

variables {
  name                = "katachi-test-pg"
  resource_group_name = "katachi-test"
  location            = "centralus"
  delegated_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/postgres"
  private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Network/privateDnsZones/katachi-test.private.postgres.database.azure.com"
  admin_vault_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.KeyVault/vaults/kat-test-adm"
}

run "the_version_is_the_development_databases" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server.this.version == "15"
    error_message = "What is tested is what runs: the development database is PostgreSQL 15 (measured 2026-11-05)."
  }
}

run "the_tier_holds_the_pools" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server.this.sku_name == "B_Standard_B2s" && output.max_user_connections == 414
    error_message = "B2s allows 414 user connections; the manifests can open 120, which B1ms's 35 cannot hold."
  }
}

run "a_tier_whose_limit_nobody_measured_is_refused" {
  command = plan

  variables {
    sku_name = "GP_Standard_D2s_v3"
  }

  expect_failures = [var.sku_name]
}

run "there_is_no_public_door" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server.this.public_network_access_enabled == false
    error_message = "The database answers only inside its network."
  }
}

run "tls_1_3_only" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server_configuration.ssl_min_protocol_version.name == "ssl_min_protocol_version" && azurerm_postgresql_flexible_server_configuration.ssl_min_protocol_version.value == "TLSv1.3"
    error_message = "Every connection is TLS 1.3 (ARD-043)."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server_configuration.require_secure_transport.name == "require_secure_transport" && azurerm_postgresql_flexible_server_configuration.require_secure_transport.value == "ON"
    error_message = "A plaintext connection is refused."
  }
}

run "the_password_never_reaches_the_plan" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server.this.administrator_password == null && azurerm_postgresql_flexible_server.this.administrator_password_wo_version == 1
    error_message = "The administrator's password goes through the write-only argument, never the stored one."
  }

  assert {
    condition     = azurerm_key_vault_secret.admin_password.value == null && azurerm_key_vault_secret.admin_password.value_wo_version == 1
    error_message = "The vault copy goes through the write-only argument too, so neither plan nor state holds it."
  }
}

run "a_backup_can_be_restored_to_any_point_in_a_week" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server.this.backup_retention_days == 7
    error_message = "Point-in-time recovery for 7 days."
  }
}

# KAT-648 T-004: Azure creates only the extensions this server parameter lists, and
# migration 740e8f18541a creates pg_trgm — so the first migration on Azure would fail.
run "the_extensions_the_migrations_create_are_allowed" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server_configuration.extensions.name == "azure.extensions" && contains(split(",", azurerm_postgresql_flexible_server_configuration.extensions.value), "PG_TRGM")
    error_message = "pg_trgm is created by a migration, so azure.extensions lists it."
  }
}

# KAT-648 T-005, from trivy config (AZU-0019, AZU-0021, AZU-0024): the server says who
# connected and when it checkpointed, and slows a run of failed sign-ins.
run "the_server_logs_connections_and_throttles_failed_sign_ins" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server_configuration.log_connections.name == "log_connections" && azurerm_postgresql_flexible_server_configuration.log_connections.value == "on"
    error_message = "Every connection is logged."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server_configuration.log_checkpoints.name == "log_checkpoints" && azurerm_postgresql_flexible_server_configuration.log_checkpoints.value == "on"
    error_message = "Checkpoints are logged."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server_configuration.connection_throttle.name == "connection_throttle.enable" && azurerm_postgresql_flexible_server_configuration.connection_throttle.value == "on"
    error_message = "Repeated failed sign-ins from one address are slowed."
  }
}
