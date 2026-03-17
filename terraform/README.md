# Terraform

Infrastructure-as-Code modules for Azure resources, written for production use.
All modules follow a consistent variable/output pattern and are designed to be
composed into larger root configurations.

## Modules

| Module | Description |
|--------|-------------|
| `azure-aks-cluster` | AKS cluster with dedicated node pool, VNet, and subnet |
| `azure-storage` | Storage account with blob container and lifecycle policy |

## Usage

```bash
cd azure-aks-cluster
terraform init
terraform plan -var-file="env/dev.tfvars"
terraform apply -var-file="env/dev.tfvars"
```

## Requirements

- Terraform >= 1.5
- AzureRM provider >= 3.80
- Azure CLI authenticated (`az login`) or service principal via environment variables
