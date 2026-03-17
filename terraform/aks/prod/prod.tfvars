###############################################################################
# prod.tfvars — AKS Cluster (prod)
###############################################################################

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------
resource_group_name = "rg-aks-prod"
environment         = "prod"
cluster_name        = "aks-prod"
location            = "eastus2"
kubernetes_version  = "1.29"

# ---------------------------------------------------------------------------
# Networking — dedicated CIDR, no overlap with nonprod (10.20.x.x)
# ---------------------------------------------------------------------------
vnet_address_space = "10.10.0.0/16"
aks_subnet_prefix  = "10.10.1.0/24"

# ---------------------------------------------------------------------------
# System node pool — HA minimum of 2 nodes across zones
# ---------------------------------------------------------------------------
system_node_vm_size   = "Standard_D4s_v5"
system_node_count     = 2
system_node_min_count = 2
system_node_max_count = 4

# ---------------------------------------------------------------------------
# App node pool — sized for production traffic with headroom to scale
# ---------------------------------------------------------------------------
app_node_vm_size   = "Standard_D4s_v5"
app_node_min_count = 3
app_node_max_count = 20

# ---------------------------------------------------------------------------
# Workload Identity
# ---------------------------------------------------------------------------
fastapi_namespace            = "api"
fastapi_service_account_name = "fastapi-sa"
acr_id                       = ""

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------
tags = {
  environment = "prod"
  managed_by  = "terraform"
  team        = "platform"
  cost_center = "engineering"
}
