# KAT-648 T-005 — the cluster. The properties ARD-059 and the plan state, each one
# watched failing before the module existed.
mock_provider "azurerm" {}

variables {
  name                       = "katachi-test-aks"
  resource_group_name        = "katachi-test"
  location                   = "centralus"
  dns_prefix                 = "katachi-test"
  tenant_id                  = "00000000-0000-0000-0000-000000000001"
  node_subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.OperationalInsights/workspaces/logs"
}

run "local_accounts_are_off_and_rights_come_from_entra" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.local_account_disabled == true
    error_message = "Local accounts must be off: a static admin credential is a key nobody can revoke per person."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled == true
    error_message = "Rights in the cluster are Azure role assignments, so the pipeline's can be limited to one namespace."
  }
}

run "the_cluster_pulls_images_as_its_own_kubelet_identity" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.identity[0].type == "UserAssigned" && length(azurerm_kubernetes_cluster.this.kubelet_identity) == 1
    error_message = "The kubelet identity is made here, so its AcrPull grant outlives the cluster."
  }

  assert {
    condition     = azurerm_role_assignment.control_plane_operates_kubelet.role_definition_name == "Managed Identity Operator"
    error_message = "AKS needs its control-plane identity to operate the kubelet identity."
  }

  assert {
    condition     = azurerm_role_assignment.control_plane_joins_subnet.role_definition_name == "Network Contributor" && azurerm_role_assignment.control_plane_joins_subnet.scope == var.node_subnet_id
    error_message = "A user-assigned control-plane identity needs Network Contributor on the node subnet; AKS does not grant it."
  }
}

run "workload_identity_is_on" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled && azurerm_kubernetes_cluster.this.workload_identity_enabled
    error_message = "Each unit signs in to Azure as its own identity, which needs the OIDC issuer and workload identity."
  }
}

run "the_vault_driver_is_on_and_rotates" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_rotation_enabled == true
    error_message = "The Secrets Store CSI driver brings the vault's values to the pods, and must pick up a rotation."
  }
}

run "the_network_is_azure_cni_overlay_on_cilium" {
  command = plan

  assert {
    condition = (
      azurerm_kubernetes_cluster.this.network_profile[0].network_plugin == "azure" &&
      azurerm_kubernetes_cluster.this.network_profile[0].network_plugin_mode == "overlay" &&
      azurerm_kubernetes_cluster.this.network_profile[0].network_data_plane == "cilium" &&
      azurerm_kubernetes_cluster.this.network_profile[0].network_policy == "cilium"
    )
    error_message = "The plan decided Azure CNI overlay with the Cilium data plane and network policy."
  }
}

run "patches_arrive_on_their_own" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.automatic_upgrade_channel == "patch" && azurerm_kubernetes_cluster.this.node_os_upgrade_channel == "NodeImage"
    error_message = "Kubernetes patch releases and node images must upgrade automatically."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.run_command_enabled == false
    error_message = "Run command lets anyone with the Azure right run kubectl as the cluster; it stays off."
  }
}

run "two_nodes_that_are_not_burstable" {
  command = plan

  assert {
    condition = (
      azurerm_kubernetes_cluster.this.default_node_pool[0].vm_size == "Standard_D2as_v5" &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].auto_scaling_enabled == true &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].min_count == 2 &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].max_count == 3
    )
    error_message = "Two Standard_D2as_v5 nodes, scaling to three."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.node_provisioning_profile[0].mode == "Manual"
    error_message = "Nodes come from the declared pool and its autoscaler, not from node auto-provisioning."
  }
}

run "a_burstable_node_is_refused" {
  command = plan

  variables {
    node_vm_size = "Standard_B2s"
  }

  expect_failures = [var.node_vm_size]
}

run "the_audit_log_leaves_the_cluster" {
  command = plan

  assert {
    condition     = contains([for l in azurerm_monitor_diagnostic_setting.audit.enabled_log : l.category], "kube-audit-admin")
    error_message = "Who changed what in the cluster must be written somewhere the cluster cannot erase."
  }
}

# KAT-648 T-005: staging is stopped on a schedule and on demand (the founder,
# 2026-11-07), and Azure cannot stop a cluster whose nodes Node Autoprovisioning makes
# (Microsoft, "Stop and start an AKS cluster"). Nodes come from the one pool.
run "the_cluster_can_be_stopped" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.node_provisioning_profile[0].mode == "Manual"
    error_message = "Node Autoprovisioning stops a cluster from being stopped; the pool's autoscaler makes the nodes."
  }
}
