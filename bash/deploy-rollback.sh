#!/usr/bin/env bash
# =============================================================================
# deploy-rollback.sh
#
# Deploys a new Docker image tag to an AKS Kubernetes Deployment and
# automatically rolls back if the health check fails within a timeout window.
#
# Usage:
#   ./deploy-rollback.sh [OPTIONS]
#
# Options:
#   -d, --deployment <name>    Kubernetes Deployment name (required)
#   -i, --image      <image>   Full image reference incl. tag (required)
#                              e.g. myacr.azurecr.io/api:1.2.3
#   -n, --namespace  <ns>      Kubernetes namespace (default: default)
#   -c, --container  <name>    Container name to update (default: same as deployment)
#   -t, --timeout    <sec>     Rollout wait timeout in seconds (default: 300)
#   --health-url     <url>     HTTP health endpoint to check post-deploy
#   --health-retries <int>     Number of health check attempts (default: 10)
#   --dry-run                  Show commands without executing
#   -h, --help
#
# Exit codes:
#   0 — deployment and health check succeeded
#   1 — deployment failed or health check failed (rollback attempted)
#   2 — script/argument error
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DEPLOYMENT=""
IMAGE=""
NAMESPACE="default"
CONTAINER=""        # Defaults to DEPLOYMENT name if not set
TIMEOUT=300
HEALTH_URL=""
HEALTH_RETRIES=10
DRY_RUN=false
ROLLBACK_PERFORMED=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
err()  { log "ERROR $*" >&2; }

run() {
  # Wrapper: print the command, then execute (or skip in dry-run)
  info "  CMD: $*"
  if [[ "$DRY_RUN" == false ]]; then
    "$@"
  fi
}

usage() {
  sed -n '/^# Usage:/,/^# Exit codes:/p' "$0" | sed 's/^# *//'
  exit 0
}

die() { err "$*"; exit 2; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--deployment)    DEPLOYMENT="$2";     shift 2 ;;
    -i|--image)         IMAGE="$2";          shift 2 ;;
    -n|--namespace)     NAMESPACE="$2";      shift 2 ;;
    -c|--container)     CONTAINER="$2";      shift 2 ;;
    -t|--timeout)       TIMEOUT="$2";        shift 2 ;;
    --health-url)       HEALTH_URL="$2";     shift 2 ;;
    --health-retries)   HEALTH_RETRIES="$2"; shift 2 ;;
    --dry-run)          DRY_RUN=true;        shift   ;;
    -h|--help)          usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
[[ -z "$DEPLOYMENT" ]] && die "--deployment is required."
[[ -z "$IMAGE"      ]] && die "--image is required."
CONTAINER="${CONTAINER:-$DEPLOYMENT}"

for cmd in kubectl curl; do
  command -v "$cmd" &>/dev/null || die "'$cmd' is required but not installed."
done

[[ "$DRY_RUN" == true ]] && warn "DRY-RUN mode — no changes will be made."

CONTEXT=$(kubectl config current-context)
info "Cluster context  : $CONTEXT"
info "Namespace        : $NAMESPACE"
info "Deployment       : $DEPLOYMENT"
info "Container        : $CONTAINER"
info "New image        : $IMAGE"
info "Rollout timeout  : ${TIMEOUT}s"

# ---------------------------------------------------------------------------
# Capture the previous image tag for rollback reference
# ---------------------------------------------------------------------------
PREV_IMAGE=""
if [[ "$DRY_RUN" == false ]]; then
  PREV_IMAGE=$(kubectl get deployment "$DEPLOYMENT" \
    -n "$NAMESPACE" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name=='${CONTAINER}')].image}" \
    2>/dev/null || echo "unknown")
  info "Previous image   : $PREV_IMAGE"
fi

# ---------------------------------------------------------------------------
# Rollback function
# ---------------------------------------------------------------------------
rollback() {
  warn "Initiating rollback for deployment '${DEPLOYMENT}'…"
  if [[ "$DRY_RUN" == false ]]; then
    kubectl rollout undo deployment/"$DEPLOYMENT" -n "$NAMESPACE" || true
    kubectl rollout status deployment/"$DEPLOYMENT" \
      -n "$NAMESPACE" \
      --timeout="${TIMEOUT}s" || warn "Rollback rollout status check failed — investigate manually."
    ROLLBACK_PERFORMED=true
  else
    info "[DRY-RUN] Would run: kubectl rollout undo deployment/${DEPLOYMENT} -n ${NAMESPACE}"
  fi
}

# ---------------------------------------------------------------------------
# Step 1: Apply the new image
# ---------------------------------------------------------------------------
info "=== Step 1: Updating image ==="
run kubectl set image \
  deployment/"$DEPLOYMENT" \
  "${CONTAINER}=${IMAGE}" \
  -n "$NAMESPACE"

run kubectl annotate deployment/"$DEPLOYMENT" \
  kubernetes.io/change-cause="Deploy ${IMAGE} via deploy-rollback.sh at $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -n "$NAMESPACE" \
  --overwrite

# ---------------------------------------------------------------------------
# Step 2: Wait for the rollout to complete
# ---------------------------------------------------------------------------
info "=== Step 2: Waiting for rollout (timeout: ${TIMEOUT}s) ==="

ROLLOUT_OK=true
if [[ "$DRY_RUN" == false ]]; then
  if ! kubectl rollout status deployment/"$DEPLOYMENT" \
       -n "$NAMESPACE" \
       --timeout="${TIMEOUT}s"; then
    warn "Rollout did not complete within ${TIMEOUT}s."
    ROLLOUT_OK=false
  fi
fi

if [[ "$ROLLOUT_OK" == false ]]; then
  err "Rollout FAILED. Rolling back…"
  rollback
  exit 1
fi

info "Rollout completed successfully."

# ---------------------------------------------------------------------------
# Step 3: HTTP health check (optional)
# ---------------------------------------------------------------------------
if [[ -n "$HEALTH_URL" ]]; then
  info "=== Step 3: Health check (${HEALTH_URL}) — ${HEALTH_RETRIES} retries ==="
  HEALTH_OK=false

  for attempt in $(seq 1 "$HEALTH_RETRIES"); do
    info "  Attempt ${attempt}/${HEALTH_RETRIES}…"
    HTTP_CODE=0

    if [[ "$DRY_RUN" == false ]]; then
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 10 \
        --retry 0 \
        "$HEALTH_URL" || echo "000")
    else
      HTTP_CODE="200"   # Simulate success in dry-run
    fi

    if [[ "$HTTP_CODE" =~ ^2 ]]; then
      info "  Health check passed (HTTP ${HTTP_CODE})."
      HEALTH_OK=true
      break
    else
      warn "  Health check returned HTTP ${HTTP_CODE}."
      sleep 15
    fi
  done

  if [[ "$HEALTH_OK" == false ]]; then
    err "Health check failed after ${HEALTH_RETRIES} attempts. Rolling back…"
    rollback
    exit 1
  fi
else
  info "=== Step 3: No health URL specified — skipping HTTP check ==="
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
echo ""
info "=== Deployment Summary ==="
info "  Status      : SUCCESS"
info "  Deployment  : $DEPLOYMENT"
info "  Namespace   : $NAMESPACE"
info "  New image   : $IMAGE"
info "  Prev image  : ${PREV_IMAGE:-n/a}"
info "  Rollback    : $ROLLBACK_PERFORMED"
[[ "$DRY_RUN" == true ]] && info "  (Dry-run — no actual changes were made)"

exit 0
