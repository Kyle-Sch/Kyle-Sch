# Package Registry API

FastAPI-based REST API for tracking software packages, with Azure AI Search semantic search and Azure AI Foundry (GPT-4o) RAG chat.

## Project Structure

```
fastapi-rest/
├── app/               # Application source
│   ├── config.py      # Settings loaded from Azure Key Vault at startup
│   ├── dependencies.py# Shared FastAPI dependencies (auth, AI clients)
│   ├── main.py        # App factory, lifespan, router registration
│   ├── models.py      # Pydantic request/response models
│   └── routers/
│       ├── packages.py   # CRUD: GET/POST/PUT/PATCH/DELETE /packages
│       └── ai_search.py  # POST /search/packages, POST /search/chat
├── chart/             # Helm chart for AKS deployment
├── Dockerfile
├── docker-compose.yml
└── .env.example
```

## Secret Management

All secrets are stored in **Azure Key Vault** and loaded at startup via `DefaultAzureCredential`.
In AKS, the pod uses **Workload Identity** (no secrets in environment variables or config files).

| Key Vault Secret Name | Description |
|---|---|
| `api-key` | API key for `X-API-Key` header auth |
| `ai-search-endpoint` | Azure AI Search HTTPS endpoint |
| `ai-foundry-endpoint` | Azure AI Foundry / OpenAI endpoint |
| `openai-deployment` | GPT-4o deployment name |
| `ai-search-index` | AI Search index name |
| `cors-origins` | Comma-separated CORS origins |

## Local Development

```bash
cp .env.example .env
# Edit .env — set AZURE_KEYVAULT_URI or individual vars

# Run with Docker Compose
docker compose up --build

# Or run directly
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Deploying to AKS

```bash
# Get Terraform outputs
KEYVAULT_URI=$(terraform -chdir=../../terraform/azure-aks-cluster output -raw key_vault_uri)
WI_CLIENT_ID=$(terraform -chdir=../../terraform/azure-aks-cluster output -raw fastapi_workload_identity_client_id)
BUILD_TAG=$(Build.BuildId)

helm upgrade --install package-registry-api ./chart \
  -f chart/values.yaml \
  -f chart/values.prod.yaml \
  --set image.tag=${BUILD_TAG} \
  --set env.AZURE_KEYVAULT_URI=${KEYVAULT_URI} \
  --set "serviceAccount.annotations.azure\.workload\.identity/client-id=${WI_CLIENT_ID}" \
  --namespace api \
  --create-namespace
```
