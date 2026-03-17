#!/usr/bin/env bash
# =============================================================================
# k8s-health-check.sh
#
# Scans pod states across one or more Kubernetes namespaces and alerts on:
#   - CrashLoopBackOff
#   - OOMKilled
#   - Pending (waiting > threshold minutes)
#   - ImagePullBackOff / ErrImagePull
#   - Evicted
#
# Optionally sends a summary to a Slack webhook.
#
# Usage:
#   ./k8s-health-check.sh [OPTIONS]
#
# Options:
#   -n, --namespaces  <ns1,ns2,...>  Comma-separated list (default: all)
#   -p, --pending-threshold <min>    Minutes before Pending is flagged (default: 5)
#   --slack-webhook <url>            Slack incoming webhook URL
#   --kubeconfig <path>              Path to kubeconfig (default: ~/.kube/config)
#   -h, --help
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
NAMESPACES="--all-namespaces"
NS_LABEL="all namespaces"
PENDING_THRESHOLD_MIN=5
SLACK_WEBHOOK=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
ISSUES=()
EXIT_CODE=0

log()  { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
err()  { log "ERROR $*" >&2; }

usage() {
  sed -n '/^# Usage:/,/^# Options:/p' "$0" | sed 's/^# *//'
  grep -E '^#   -' "$0" | sed 's/^# */  /'
  exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespaces)
      IFS=',' read -ra NS_ARRAY <<< "$2"
      NS_LABEL="$2"
      shift 2
      ;;
    -p|--pending-threshold) PENDING_THRESHOLD_MIN="$2"; shift 2 ;;
    --slack-webhook)        SLACK_WEBHOOK="$2";         shift 2 ;;
    --kubeconfig)           KUBECONFIG_PATH="$2";       shift 2 ;;
    -h|--help) usage ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

export KUBECONFIG="$KUBECONFIG_PATH"

# ---------------------------------------------------------------------------
# Validate dependencies
# ---------------------------------------------------------------------------
for cmd in kubectl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "'$cmd' is required but not installed."
    exit 1
  fi
done

CONTEXT=$(kubectl config current-context)
info "Cluster context : $CONTEXT"
info "Namespaces      : $NS_LABEL"
info "Pending threshold: ${PENDING_THRESHOLD_MIN} minute(s)"

# ---------------------------------------------------------------------------
# Build kubectl namespace flags
# ---------------------------------------------------------------------------
if [[ -v NS_ARRAY ]]; then
  # Check specific namespaces
  NS_FLAGS=()
  for ns in "${NS_ARRAY[@]}"; do
    NS_FLAGS+=("$ns")
  done
else
  NS_FLAGS=("--all-namespaces")
fi

# ---------------------------------------------------------------------------
# Fetch all pods as JSON
# ---------------------------------------------------------------------------
info "Fetching pod list…"

if [[ "${NS_FLAGS[*]}" == "--all-namespaces" ]]; then
  POD_JSON=$(kubectl get pods --all-namespaces -o json)
else
  # Merge pods from each namespace
  POD_JSON='{"items":[]}'
  for ns in "${NS_FLAGS[@]}"; do
    NS_PODS=$(kubectl get pods -n "$ns" -o json 2>/dev/null || echo '{"items":[]}')
    POD_JSON=$(echo "$POD_JSON $NS_PODS" | jq -s '{"items": ([.[].items] | add // [])}')
  done
fi

TOTAL_PODS=$(echo "$POD_JSON" | jq '.items | length')
info "Total pods found: $TOTAL_PODS"

NOW_EPOCH=$(date -u +%s)

# ---------------------------------------------------------------------------
# Evaluate each pod
# ---------------------------------------------------------------------------
while IFS= read -r pod; do
  POD_NAME=$(echo "$pod" | jq -r '.metadata.name')
  NAMESPACE=$(echo "$pod" | jq -r '.metadata.namespace')
  PHASE=$(echo "$pod" | jq -r '.status.phase // "Unknown"')
  PREFIX="[${NAMESPACE}/${POD_NAME}]"

  # Check container statuses for specific error states
  CONTAINER_STATUSES=$(echo "$pod" | jq -c '[.status.containerStatuses // [] | .[]]')

  while IFS= read -r cs; do
    CONTAINER=$(echo "$cs" | jq -r '.name')
    REASON=$(echo "$cs" | jq -r '.state.waiting.reason // ""')
    RESTART_COUNT=$(echo "$cs" | jq -r '.restartCount // 0')

    case "$REASON" in
      CrashLoopBackOff)
        msg="${PREFIX} container '${CONTAINER}' is in CrashLoopBackOff (restarts: ${RESTART_COUNT})"
        warn "$msg"
        ISSUES+=("$msg")
        EXIT_CODE=1
        ;;
      OOMKilled)
        msg="${PREFIX} container '${CONTAINER}' was OOMKilled (restarts: ${RESTART_COUNT})"
        warn "$msg"
        ISSUES+=("$msg")
        EXIT_CODE=1
        ;;
      ImagePullBackOff|ErrImagePull)
        IMAGE=$(echo "$cs" | jq -r '.image // "unknown"')
        msg="${PREFIX} container '${CONTAINER}' cannot pull image '${IMAGE}' (${REASON})"
        warn "$msg"
        ISSUES+=("$msg")
        EXIT_CODE=1
        ;;
    esac

    # Check for OOMKilled in terminated state (pod may have restarted)
    TERM_REASON=$(echo "$cs" | jq -r '.lastState.terminated.reason // ""')
    if [[ "$TERM_REASON" == "OOMKilled" ]]; then
      msg="${PREFIX} container '${CONTAINER}' was previously OOMKilled"
      warn "$msg"
      ISSUES+=("$msg")
    fi

  done < <(echo "$CONTAINER_STATUSES" | jq -c '.[]')

  # Check for Pending pods exceeding the threshold
  if [[ "$PHASE" == "Pending" ]]; then
    START_TIME=$(echo "$pod" | jq -r '.metadata.creationTimestamp // ""')
    if [[ -n "$START_TIME" ]]; then
      START_EPOCH=$(date -u -d "$START_TIME" +%s 2>/dev/null || \
                    date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +%s)
      PENDING_MIN=$(( (NOW_EPOCH - START_EPOCH) / 60 ))
      if (( PENDING_MIN >= PENDING_THRESHOLD_MIN )); then
        UNSCHEDULABLE=$(echo "$pod" | jq -r \
          '[.status.conditions[]? | select(.type=="PodScheduled") | .message] | first // ""')
        msg="${PREFIX} has been Pending for ${PENDING_MIN} minute(s). Reason: ${UNSCHEDULABLE:-unknown}"
        warn "$msg"
        ISSUES+=("$msg")
        EXIT_CODE=1
      fi
    fi
  fi

  # Check for Evicted pods
  if [[ "$PHASE" == "Failed" ]]; then
    EVICT_REASON=$(echo "$pod" | jq -r '.status.reason // ""')
    if [[ "$EVICT_REASON" == "Evicted" ]]; then
      msg="${PREFIX} has been Evicted"
      warn "$msg"
      ISSUES+=("$msg")
      EXIT_CODE=1
    fi
  fi

done < <(echo "$POD_JSON" | jq -c '.items[]')

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
info "=== Health Check Summary ==="
info "  Context    : $CONTEXT"
info "  Namespaces : $NS_LABEL"
info "  Total pods : $TOTAL_PODS"
info "  Issues     : ${#ISSUES[@]}"

if [[ ${#ISSUES[@]} -eq 0 ]]; then
  info "  Status     : ALL PODS HEALTHY"
else
  warn "  Status     : DEGRADED — ${#ISSUES[@]} issue(s) found"
  for issue in "${ISSUES[@]}"; do
    warn "    - $issue"
  done
fi

# ---------------------------------------------------------------------------
# Slack notification
# ---------------------------------------------------------------------------
if [[ -n "$SLACK_WEBHOOK" && ${#ISSUES[@]} -gt 0 ]]; then
  ISSUE_LIST=$(printf '• %s\n' "${ISSUES[@]}")
  PAYLOAD=$(jq -nc \
    --arg ctx "$CONTEXT" \
    --arg ns "$NS_LABEL" \
    --arg count "${#ISSUES[@]}" \
    --arg issues "$ISSUE_LIST" \
    '{
      text: ":red_circle: *K8s Health Alert* — \($count) issue(s) in \($ctx) [\($ns)]",
      blocks: [
        {type:"section", text:{type:"mrkdwn",
          text:"*Cluster:* \($ctx)\n*Namespaces:* \($ns)\n*Issues found:* \($count)"}},
        {type:"section", text:{type:"mrkdwn", text:"```\($issues)```"}}
      ]
    }')

  if curl -s -X POST -H "Content-Type: application/json" \
       --data "$PAYLOAD" "$SLACK_WEBHOOK" > /dev/null; then
    info "Slack notification sent."
  else
    warn "Failed to send Slack notification."
  fi
fi

exit $EXIT_CODE
