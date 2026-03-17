###############################################################################
# terraform.tfvars — AKS Cluster (nonprod)
###############################################################################

resource_group_name          = "rg-aks-nonprod"
environment                  = "dev"
cluster_name                 = "aks-nonprod"
location                     = "eastus2"
kubernetes_version           = "1.29"
vnet_address_space           = "10.20.0.0/16"
aks_subnet_prefix            = "10.20.1.0/24"
system_node_vm_size          = "Standard_D2s_v5"
system_node_count            = 1
system_node_min_count        = 1
system_node_max_count        = 2
app_node_vm_size             = "Standard_D2s_v5"
app_node_min_count           = 1
app_node_max_count           = 3
fastapi_namespace            = "api"
fastapi_service_account_name = "fastapi-sa"
acr_id                       = ""

tags = {
  environment = "nonprod"
  managed_by  = "terraform"
  team        = "platform"
}
