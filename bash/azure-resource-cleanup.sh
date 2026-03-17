#!/usr/bin/env bash
# =============================================================================
# azure-resource-cleanup.sh
#
# Finds Azure resource groups whose creation date is older than N days and
# optionally deletes them. Designed to clean up ephemeral dev/test environments.
#
# Usage:
#   ./azure-resource-cleanup.sh [OPTIONS]
#
# Options:
#   -d, --days    <int>   Delete RGs older than this many days (default: 30)
#   -t, --tag     <key=value>  Only consider RGs with this tag (e.g. env=dev)
#   -s, --subscription <id>   Azure subscription ID (default: current)
#   --dry-run               Print what would be deleted without deleting
#   -h, --help              Show this help
#
# Requirements:
#   az CLI (authenticated), jq
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DAYS=30
TAG_FILTER=""
SUBSCRIPTION=""
DRY_RUN=false
DELETED=0
SKIPPED=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
err()  { log "ERROR $*" >&2; }

usage() {
  sed -n '/^# Usage:/,/^# Requirements:/p' "$0" | sed 's/^# *//'
  exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--days)         DAYS="$2";         shift 2 ;;
    -t|--tag)          TAG_FILTER="$2";   shift 2 ;;
    -s|--subscription) SUBSCRIPTION="$2"; shift 2 ;;
    --dry-run)         DRY_RUN=true;      shift   ;;
    -h|--help)         usage ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate dependencies
# ---------------------------------------------------------------------------
for cmd in az jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "'$cmd' is required but not installed."
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Set subscription if provided
# ---------------------------------------------------------------------------
if [[ -n "$SUBSCRIPTION" ]]; then
  info "Setting subscription to: $SUBSCRIPTION"
  az account set --subscription "$SUBSCRIPTION"
fi

CURRENT_SUB=$(az account show --query "name" -o tsv)
info "Running against subscription: $CURRENT_SUB"
info "Threshold: resource groups older than ${DAYS} day(s)"
[[ "$DRY_RUN" == true ]] && warn "DRY-RUN mode — no resources will be deleted."

# ---------------------------------------------------------------------------
# Compute cutoff epoch
# ---------------------------------------------------------------------------
CUTOFF_EPOCH=$(date -u -d "-${DAYS} days" +%s 2>/dev/null || date -u -v-"${DAYS}"d +%s)

# ---------------------------------------------------------------------------
# List resource groups
# ---------------------------------------------------------------------------
TAG_ARGS=()
if [[ -n "$TAG_FILTER" ]]; then
  TAG_ARGS=(--tag "$TAG_FILTER")
  info "Filtering by tag: $TAG_FILTER"
fi

info "Fetching resource groups…"
RG_JSON=$(az group list "${TAG_ARGS[@]}" -o json)

TOTAL=$(echo "$RG_JSON" | jq 'length')
info "Found ${TOTAL} resource group(s) matching filters."

# ---------------------------------------------------------------------------
# Iterate and evaluate each resource group
# ---------------------------------------------------------------------------
while IFS= read -r rg; do
  RG_NAME=$(echo "$rg" | jq -r '.name')
  RG_LOCATION=$(echo "$rg" | jq -r '.location')

  # Retrieve creation time via activity log (first "Create or Update" event)
  CREATED_AT=$(az monitor activity-log list \
    --resource-group "$RG_NAME" \
    --operation "Microsoft.Resources/subscriptions/resourceGroups/write" \
    --status "Succeeded" \
    --max-events 1 \
    --query "[0].eventTimestamp" \
    -o tsv 2>/dev/null || echo "")

  if [[ -z "$CREATED_AT" ]]; then
    warn "Cannot determine creation date for '${RG_NAME}' — skipping."
    (( SKIPPED++ )) || true
    continue
  fi

  # Convert to epoch (GNU date / BSD date compatible)
  CREATED_EPOCH=$(date -u -d "$CREATED_AT" +%s 2>/dev/null || \
                  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED_AT" +%s)
  AGE_DAYS=$(( ($(date -u +%s) - CREATED_EPOCH) / 86400 ))

  if (( CREATED_EPOCH < CUTOFF_EPOCH )); then
    info "  CANDIDATE  '${RG_NAME}' (${RG_LOCATION}) — age: ${AGE_DAYS} days — created: ${CREATED_AT}"

    if [[ "$DRY_RUN" == true ]]; then
      info "  [DRY-RUN] Would delete: $RG_NAME"
    else
      info "  Deleting resource group '${RG_NAME}'…"
      if az group delete --name "$RG_NAME" --yes --no-wait; then
        info "  Deletion initiated for '${RG_NAME}'."
        (( DELETED++ )) || true
      else
        err "  Failed to initiate deletion of '${RG_NAME}'."
        (( SKIPPED++ )) || true
      fi
    fi
  else
    info "  KEEP       '${RG_NAME}' — age: ${AGE_DAYS} days"
  fi

done < <(echo "$RG_JSON" | jq -c '.[]')

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
info "=== Summary ==="
info "  Subscription : $CURRENT_SUB"
info "  Total RGs    : $TOTAL"
info "  Deleted      : $DELETED"
info "  Skipped      : $SKIPPED"
[[ "$DRY_RUN" == true ]] && info "  (Dry-run — nothing was actually deleted)"
