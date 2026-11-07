# KAT-648 T-005 — the database: the one thing here that cannot be rebuilt, so Azure
# runs it with point-in-time recovery (ARD-059 §7). It has no public address and
# refuses anything but TLS 1.3 (ARD-043).

locals {
  # Azure's max_connections for the tier, less the 15 it reserves. Measured for
  # KAT-648 §1 from Microsoft's limits page; a tier missing here is refused rather
  # than guessed at, because T-002's pool test reads this figure.
  max_user_connections = {
    B_Standard_B1ms = 35
    B_Standard_B2s  = 414
  }
}

# Ephemeral: made during the run and never written to the plan or the state. It
# reaches the server and the vault only through write-only arguments.
ephemeral "random_password" "admin" {
  length           = 40
  special          = true
  override_special = "-_.~"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 2
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  version    = var.postgres_version
  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  auto_grow_enabled            = true
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = false

  public_network_access_enabled = false
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id

  administrator_login               = var.admin_login
  administrator_password_wo         = ephemeral.random_password.admin.result
  administrator_password_wo_version = var.admin_password_version

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = false
  }

  tags = var.tags

  lifecycle {
    # Azure picks the zone; a later plan must not try to move the server.
    ignore_changes = [zone]
  }

  # The vault copy is written first. Each run makes a new ephemeral value and sends
  # it only to what is being created or rotated, so a run that wrote one copy and
  # failed before the other would leave them disagreeing. Writing the vault first
  # makes the likely failure (a role still propagating) happen before the server
  # exists, and the next run writes both with one value. If the server's creation
  # is what failed, raise admin_password_version and apply: both take the new value.
  depends_on = [azurerm_key_vault_secret.admin_password]
}

# A flexible server takes one parameter change at a time, and a second one sent while
# the first runs fails ("an operation is already in progress"), so each setting below
# waits for the one before it (KAT-648 T-005).
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "ON"
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl_min_protocol_version" {
  name      = "ssl_min_protocol_version"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "TLSv1.3"

  depends_on = [azurerm_postgresql_flexible_server_configuration.require_secure_transport]
}

# KAT-648 T-004: Azure creates only the extensions this lists, and a migration
# (740e8f18541a) creates pg_trgm — trusted, so the units' own role, which owns its
# database, may create it once it is allowed here.
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "PG_TRGM"

  depends_on = [azurerm_postgresql_flexible_server_configuration.ssl_min_protocol_version]
}

# The same value, into the vault only db-bootstrap reads (KAT-648 T-004). No unit
# ever connects as the administrator.
# KAT-648 T-005, from trivy config: who connected, when the server checkpointed, and a
# run of failed sign-ins from one address slowed. Free; the server keeps its own logs.
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "on"

  depends_on = [azurerm_postgresql_flexible_server_configuration.extensions]
}

resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "on"

  depends_on = [azurerm_postgresql_flexible_server_configuration.log_connections]
}

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttle" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "on"

  depends_on = [azurerm_postgresql_flexible_server_configuration.log_checkpoints]
}

resource "azurerm_key_vault_secret" "admin_password" {
  name             = var.admin_secret_name
  key_vault_id     = var.admin_vault_id
  value_wo         = ephemeral.random_password.admin.result
  value_wo_version = var.admin_password_version
  content_type     = "postgresql-administrator-password"
}
