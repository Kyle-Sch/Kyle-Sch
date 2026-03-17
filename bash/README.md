# Bash Scripts

Operational scripts for Azure resource management, Kubernetes health monitoring,
and zero-downtime deployments with automatic rollback.

## Scripts

| Script | Description |
|--------|-------------|
| `azure-resource-cleanup.sh` | Delete Azure resource groups older than N days |
| `k8s-health-check.sh` | Scan pod states across namespaces, alert on failures |
| `deploy-rollback.sh` | Deploy new image to AKS, rollback automatically on failure |

## Usage

All scripts support `--help` and use `set -euo pipefail` for safe execution.

```bash
chmod +x *.sh

./azure-resource-cleanup.sh --days 30 --dry-run
./k8s-health-check.sh --namespaces "default,api,monitoring"
./deploy-rollback.sh --deployment api-server --image myacr.azurecr.io/api:1.2.3
```

## Requirements

- `az` CLI (authenticated)
- `kubectl` (kubeconfig configured)
- `jq`
