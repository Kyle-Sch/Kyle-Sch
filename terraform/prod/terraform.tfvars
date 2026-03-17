###############################################################################
# terraform.tfvars — Platform Services (prod)
###############################################################################

resource_group_name          = "rg-aks-prod"
location                     = "eastus2"
cluster_name                 = "aks-prod"
storage_account_name         = "stapprod001"
replication_type             = "GRS"
container_names              = ["data", "logs", "archive", "backup"]
soft_delete_retention_days   = 30
allowed_ip_ranges            = []
allowed_subnet_ids           = []
ai_search_sku                = "standard"
ai_search_replica_count      = 2
ai_search_index_name         = "packages-index"
ai_foundry_sku               = "S0"
openai_deployment_name       = "gpt-4o"
gpt45_deployment_name        = "gpt-4.5"
gpt45_capacity_tpm           = 50
codex_deployment_name        = "codex"
codex_capacity_tpm           = 30
model_router_deployment_name = "model-router"
model_router_capacity_tpm    = 100
apim_sku_name                = "Standard_1"
apim_publisher_name          = "Platform Team"
apim_publisher_email         = "platform@example.com"
apim_tenant_id               = "<your-tenant-id>"
apim_audience                = "<your-app-registration-client-id>"
apim_backend_url             = "http://worker-service.api.svc.cluster.local:8080"
apim_cors_origins            = ["https://portal.example.com", "https://app.example.com"]
cors_origins                 = "https://portal.example.com"

tags = {
  environment = "prod"
  managed_by  = "terraform"
  team        = "platform"
}
