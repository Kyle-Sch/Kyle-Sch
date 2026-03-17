###############################################################################
# terraform.tfvars — Platform Services (nonprod)
###############################################################################

resource_group_name          = "rg-aks-nonprod"
location                     = "eastus2"
cluster_name                 = "aks-nonprod"
storage_account_name         = "stappnonprod001"
replication_type             = "LRS"
container_names              = ["data", "logs", "archive"]
soft_delete_retention_days   = 7
allowed_ip_ranges            = []
allowed_subnet_ids           = []
ai_search_sku                = "basic"
ai_search_replica_count      = 1
ai_search_index_name         = "packages-index-nonprod"
ai_foundry_sku               = "S0"
openai_deployment_name       = "gpt-4o"
gpt45_deployment_name        = "gpt-4.5"
gpt45_capacity_tpm           = 10
codex_deployment_name        = "codex"
codex_capacity_tpm           = 10
model_router_deployment_name = "model-router"
model_router_capacity_tpm    = 20
apim_sku_name                = "Developer_1"
apim_publisher_name          = "Platform Team"
apim_publisher_email         = "platform@example.com"
apim_tenant_id               = "<your-tenant-id>"
apim_audience                = "<your-app-registration-client-id>"
apim_backend_url             = "http://worker-service.api.svc.cluster.local:8080"
apim_cors_origins            = ["https://dev-portal.example.com", "http://localhost:3000"]
cors_origins                 = "https://dev-portal.example.com,http://localhost:3000,http://localhost:5173"

tags = {
  environment = "nonprod"
  managed_by  = "terraform"
  team        = "platform"
}
