###############################################################################
# terraform.tfvars — AKS Cluster (prod)
###############################################################################

resource_group_name          = "rg-aks-prod"
environment                  = "prod"
cluster_name                 = "aks-prod"
location                     = "eastus2"
kubernetes_version           = "1.29"
vnet_address_space           = "10.10.0.0/16"
aks_subnet_prefix            = "10.10.1.0/24"
system_node_vm_size          = "Standard_D4s_v5"
system_node_count            = 2
system_node_min_count        = 2
system_node_max_count        = 4
app_node_vm_size             = "Standard_D4s_v5"
app_node_min_count           = 3
app_node_max_count           = 20
fastapi_namespace            = "api"
fastapi_service_account_name = "fastapi-sa"
acr_id                       = ""

tags = {
  environment = "prod"
  managed_by  = "terraform"
  team        = "platform"
}
