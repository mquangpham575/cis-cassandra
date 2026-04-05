#!/usr/bin/env bash
# rolling_restart.sh — Perform a safe rolling restart of the Cassandra cluster
# Drains, stops, starts, and waits for UN state one node at a time.
# Usage: bash scripts/cluster/rolling_restart.sh
# Exit 0 = all nodes restarted successfully, Exit 1 = failure (restart aborted)
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SSH_KEY="${CIS_SSH_KEY:-$HOME/.ssh/cis_key}"
SSH_USER="${CIS_SSH_USER:-cassandra}"
NODES=("192.168.56.11" "192.168.56.12" "192.168.56.13")
SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=4)
NODE_UP_TIMEOUT="${CIS_NODE_UP_TIMEOUT:-180}"   # seconds to wait for UN state
POLL_INTERVAL=10                                  # seconds between nodetool polls
WARMUP_SLEEP="${CIS_WARMUP_SLEEP:-30}"           # seconds to wait for JVM startup

# ── Colour helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
fail() { echo -e "${RED}[FAIL]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
step() { echo -e "\n${CYAN}[STEP]${NC}  $*"; }

# Trap unexpected exits to provide context
trap 'fail "Script exited unexpectedly at line ${LINENO} — check output above"' ERR

# ── Helper: wait for a node to appear as UN ────────────────────────────────────
# Args: $1 = coordinator node IP, $2 = target node IP to wait for
wait_for_un() {
  local COORDINATOR="$1"
  local TARGET="$2"
  local ELAPSED=0

  info "Waiting for ${TARGET} to reach UN state (timeout: ${NODE_UP_TIMEOUT}s)..."

  while [ "${ELAPSED}" -lt "${NODE_UP_TIMEOUT}" ]; do
    STATUS_LINE=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${COORDINATOR}" \
      "nodetool status 2>/dev/null | awk '/^(U|D)(N|L|J|M).*${TARGET}/{print \$1}'" \
      2>/dev/null || echo "")

    if [ "${STATUS_LINE}" = "UN" ]; then
      ok "${TARGET} is now UN — elapsed ${ELAPSED}s"
      return 0
    fi

    info "  ${TARGET} current state: ${STATUS_LINE:-UNKNOWN} — retrying in ${POLL_INTERVAL}s..."
    sleep "${POLL_INTERVAL}"
    ELAPSED=$(( ELAPSED + POLL_INTERVAL ))
  done

  fail "Timeout: ${TARGET} did not reach UN within ${NODE_UP_TIMEOUT}s"
  return 1
}

# ── Pre-flight checks ──────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  CIS Cassandra Rolling Restart"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Nodes: ${NODES[*]}"
echo "════════════════════════════════════════════════════════════"
echo ""

info "Pre-flight: verifying all nodes are reachable..."
for NODE in "${NODES[@]}"; do
  if ! ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" "echo ok" &>/dev/null; then
    fail "Node ${NODE} is unreachable — aborting"
    exit 1
  fi
  ok "  ${NODE} reachable"
done

echo ""
info "Pre-flight: verifying all nodes are UN before restart..."
COORDINATOR="${NODES[0]}"
for NODE in "${NODES[@]}"; do
  STATE=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${COORDINATOR}" \
    "nodetool status 2>/dev/null | awk '/^(U|D)(N|L|J|M).*${NODE}/{print \$1}'" 2>/dev/null || echo "UNKNOWN")
  if [ "${STATE}" != "UN" ]; then
    fail "Node ${NODE} is not UN (state: ${STATE:-UNKNOWN}) — aborting"
    exit 1
  fi
  ok "  ${NODE} is UN"
done

echo ""
info "Pre-flight passed. Starting rolling restart of ${#NODES[@]} nodes..."

# ── Rolling restart ────────────────────────────────────────────────────────────
RESTART_SUCCESS=true
FAILED_NODE=""

for i in "${!NODES[@]}"; do
  NODE="${NODES[$i]}"
  NODE_NUM=$(( i + 1 ))

  echo ""
  echo "════════════════════════════════════════════════════════════"
  step "Node ${NODE_NUM}/${#NODES[@]}: ${NODE}"
  echo "════════════════════════════════════════════════════════════"

  # A) Drain
  step "A) nodetool drain on ${NODE}..."
  if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" "sudo timeout 300 nodetool drain"; then
    ok "drain complete on ${NODE}"
  else
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -eq 124 ]; then
      fail "drain TIMED OUT on ${NODE} (exceeded 300s) — aborting"
    else
      fail "drain FAILED on ${NODE} (exit ${EXIT_CODE}) — aborting"
    fi
    RESTART_SUCCESS=false
    FAILED_NODE="${NODE}"
    break
  fi
  sleep 5

  # B) Stop
  step "B) Stopping Cassandra on ${NODE}..."
  if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" "sudo systemctl stop cassandra"; then
    ok "Cassandra stopped on ${NODE}"
  else
    fail "stop FAILED on ${NODE} — aborting"
    RESTART_SUCCESS=false
    FAILED_NODE="${NODE}"
    break
  fi

  # C) Start
  step "C) Starting Cassandra on ${NODE}..."
  if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" "sudo systemctl start cassandra"; then
    ok "Cassandra start issued on ${NODE}"
  else
    fail "start FAILED on ${NODE} — aborting"
    RESTART_SUCCESS=false
    FAILED_NODE="${NODE}"
    break
  fi

  # D) Wait for UN — use next node as coordinator, or first node if this is the last
  if [ $(( i + 1 )) -lt "${#NODES[@]}" ]; then
    COORD="${NODES[$(( i + 1 ))]}"
  else
    COORD="${NODES[0]}"
  fi

  # Fast-fail: if the service crashed immediately after start, don't wait 30s+
  sleep 3
  IMMEDIATE_STATE=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" \
    "sudo systemctl is-active cassandra 2>/dev/null || echo failed")
  if [ "${IMMEDIATE_STATE}" = "failed" ] || [ "${IMMEDIATE_STATE}" = "inactive" ]; then
    fail "Cassandra crashed immediately after start on ${NODE} (state: ${IMMEDIATE_STATE})"
    fail "Check: ssh ${SSH_USER}@${NODE} 'sudo journalctl -u cassandra -n 30'"
    RESTART_SUCCESS=false
    FAILED_NODE="${NODE}"
    break
  fi
  info "Cassandra is ${IMMEDIATE_STATE} on ${NODE} — proceeding with warmup wait"

  info "Waiting ${WARMUP_SLEEP}s for JVM warmup before polling ${NODE}..."
  sleep "${WARMUP_SLEEP}"

  if ! wait_for_un "${COORD}" "${NODE}"; then
    fail "${NODE} failed to reach UN — aborting"
    RESTART_SUCCESS=false
    FAILED_NODE="${NODE}"
    break
  fi

  # E) Mini health-check before proceeding to next node
  UN_COUNT=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${COORD}" \
    "nodetool status 2>/dev/null | grep -c '^UN'" 2>/dev/null || echo "0")
  ok "Cluster state after restarting ${NODE}: ${UN_COUNT}/${#NODES[@]} nodes UN"

  if [ $(( i + 1 )) -lt "${#NODES[@]}" ]; then
    info "Pausing 15s before next node..."
    sleep 15
  fi
done

# ── Final summary ──────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Rolling Restart Summary — $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════════════════"

if [ "${RESTART_SUCCESS}" = true ]; then
  FINAL_STATUS=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODES[0]}" \
    "nodetool status 2>/dev/null" 2>/dev/null || echo "(nodetool unavailable)")
  echo ""
  echo "${FINAL_STATUS}" | sed 's/^/  /'
  echo ""
  FINAL_UN=$(echo "${FINAL_STATUS}" | grep -c "^UN" || true)
  if [ "${FINAL_UN}" -eq "${#NODES[@]}" ]; then
    ok "Rolling restart succeeded — ALL ${#NODES[@]} nodes UN"
    exit 0
  else
    warn "Rolling restart finished but only ${FINAL_UN}/${#NODES[@]} nodes are UN"
    exit 1
  fi
else
  fail "Rolling restart FAILED — manual intervention required"
  if [ -n "${FAILED_NODE}" ]; then
    fail "Check: ssh ${SSH_USER}@${FAILED_NODE} 'sudo journalctl -u cassandra -n 50'"
  else
    fail "Check journalctl on the affected node"
  fi
  exit 1
fi
