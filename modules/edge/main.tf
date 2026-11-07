# KAT-648 T-005 — the address Envoy Gateway answers on (T-007), and its DNS when the
# zone is ours to serve.

resource "azurerm_public_ip" "gateway" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_role_assignment" "cluster_network" {
  scope                = azurerm_public_ip.gateway.id
  role_definition_name = "Network Contributor"
  principal_id         = var.cluster_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_dns_zone" "this" {
  count = var.dns_zone_name == "" ? 0 : 1

  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

locals {
  hosts = var.dns_zone_name == "" ? {} : {
    app = var.app_host
    mcp = var.mcp_host
  }

  relative_names = {
    for k, host in local.hosts : k => (host == var.dns_zone_name ? "@" : trimsuffix(host, ".${var.dns_zone_name}"))
  }
}

# Alias records follow the address itself, so they cannot point at a stale one.
resource "azurerm_dns_a_record" "host" {
  for_each = local.relative_names

  name                = each.value
  zone_name           = azurerm_dns_zone.this[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.gateway.id
  tags                = var.tags
}
