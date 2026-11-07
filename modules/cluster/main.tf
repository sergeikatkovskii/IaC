# KAT-648 T-005 — the cluster (ARD-059). Every property here is asserted in
# tests/cluster.tftest.hcl, and each was watched failing before this file existed.

# Both of the cluster's own identities are made here rather than by AKS. The
# kubelet identity is the one that pulls images, so its AcrPull grant survives a
# rebuilt cluster; AKS requires a user-assigned control-plane identity to use it,
# and that identity must be allowed to operate the kubelet one.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "${var.name}-control-plane"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${var.name}-kubelet"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "control_plane_operates_kubelet" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

# A user-assigned control-plane identity must be able to join the node subnet;
# AKS grants that itself only for a system-assigned one.
resource "azurerm_role_assignment" "control_plane_joins_subnet" {
  scope                = var.node_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # No static admin credential: everyone signs in with Entra ID, and rights inside
  # the cluster are Azure role assignments. That is what lets the pipeline's be
  # limited to the namespace tcm-system (KAT-648 §8 Q10).
  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  # Each unit signs in to Azure as its own identity (ARD-018, ARD-040).
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Run command would let anyone with the Azure right run kubectl as the cluster.
  run_command_enabled = false

  automatic_upgrade_channel    = "patch"
  node_os_upgrade_channel      = "NodeImage"
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    vnet_subnet_id              = var.node_subnet_id
    auto_scaling_enabled        = true
    min_count                   = var.node_min_count
    max_count                   = var.node_max_count
    temporary_name_for_rotation = "systemtmp"
    tags                        = var.tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Nodes come from the one pool above and its autoscaler, not from node
  # auto-provisioning; azurerm 5 requires the choice to be stated.
  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  # The Secrets Store CSI driver brings the vault's values to the pods, and picks up
  # a rotation within two minutes (KAT-648 T-003).
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  tags = var.tags

  lifecycle {
    # The autoscaler owns the node count.
    ignore_changes = [default_node_pool[0].node_count]
  }

  depends_on = [
    azurerm_role_assignment.control_plane_operates_kubelet,
    azurerm_role_assignment.control_plane_joins_subnet,
  ]
}

# Who changed what inside the cluster, kept where the cluster cannot erase it.
# kube-audit-admin leaves out reads, which are most of the volume.
resource "azurerm_monitor_diagnostic_setting" "audit" {
  name                           = "katachi-cluster-audit"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }
}
