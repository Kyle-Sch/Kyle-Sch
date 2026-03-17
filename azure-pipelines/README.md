# Azure Pipelines

Azure DevOps pipeline definitions covering CI/CD for .NET and Python applications
as well as infrastructure deployments via Terraform.

## Pipelines

| File | Purpose |
|------|---------|
| `ci-cd-dotnet.yml` | Build, test, SonarQube gate, push to ACR, deploy to AKS (.NET) |
| `ci-cd-python.yml` | Lint, pytest, Docker build/push, deploy (Python) |
| `infra-terraform-pipeline.yml` | Terraform init/plan/apply with manual approval gate |

## Variable Groups

Pipelines reference the following Azure DevOps variable groups (configured in the portal):

- `acr-credentials` — ACR login server, username, password
- `aks-credentials` — AKS resource group, cluster name
- `sonarqube` — SonarQube host URL and token
- `terraform-sp` — ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
