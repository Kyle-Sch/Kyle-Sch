###############################################################################
# AKS Cluster — main.tf
# Creates: Resource Group, VNet + Subnet, AKS cluster with a system node pool
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  # Remote state — swap out the values for your environment
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate"
    container_name       = "tfstate"
    key                  = "aks/prod/aks-cluster.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
  }
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Networking — VNet and dedicated AKS subnet
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "aks" {
  name                = "vnet-${var.cluster_name}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = [var.vnet_address_space]

  tags = var.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace (for Container Insights)
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "law-${var.cluster_name}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# ---------------------------------------------------------------------------
# AKS Cluster
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # System node pool — keep tainted for system workloads only
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_nodes.id
    os_disk_size_gb     = 128
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = var.system_node_min_count
    max_count           = var.system_node_max_count

    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }

    # Prevent user workloads from landing on the system pool
    node_taints = ["CriticalAddonsOnly=true:NoSchedule"]
  }

  # Managed identity — avoids storing service principal credentials
  identity {
    type = "SystemAssigned"
  }

  # Azure CNI for full VNet integration
  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    load_balancer_sku  = "standard"
    service_cidr       = "10.100.0.0/16"
    dns_service_ip     = "10.100.0.10"
  }

  # Container Insights
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  # Enable RBAC and Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.tags
}

# ---------------------------------------------------------------------------
# User node pool — for application workloads
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.app_node_vm_size
  vnet_subnet_id        = azurerm_subnet.aks_nodes.id
  os_disk_size_gb       = 128
  mode                  = "User"
  enable_auto_scaling   = true
  min_count             = var.app_node_min_count
  max_count             = var.app_node_max_count

  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
  }

  tags = var.tags
}
