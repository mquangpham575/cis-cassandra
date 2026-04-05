#!/usr/bin/env bash
# health_check.sh — Check Cassandra cluster health across all 3 nodes
# Usage: bash scripts/cluster/health_check.sh
# Exit 0 = all nodes healthy, Exit 1 = one or more nodes have issues
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SSH_KEY="${CIS_SSH_KEY:-$HOME/.ssh/cis_key}"
SSH_USER="${CIS_SSH_USER:-cassandra}"
NODES=("192.168.56.11" "192.168.56.12" "192.168.56.13")
SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes)

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
fail() { echo -e "${RED}[FAIL]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }

# ── Main ──────────────────────────────────────────────────────────────────────
OVERALL=0
UNREACHABLE=0
SERVICE_DOWN=0
NOT_UN=0

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  CIS Cassandra Cluster Health Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════════════════"
echo ""

for NODE in "${NODES[@]}"; do
  info "Checking node: ${NODE}"

  # 1. Can we SSH in?
  if ! ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" "echo ok" &>/dev/null; then
    fail "  ${NODE} — UNREACHABLE (SSH failed)"
    UNREACHABLE=$(( UNREACHABLE + 1 ))
    OVERALL=1
    continue
  fi

  # 2. Is Cassandra service running?
  SVC_STATE=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" \
    "sudo systemctl is-active cassandra 2>/dev/null || echo inactive")
  if [ "${SVC_STATE}" != "active" ]; then
    fail "  ${NODE} — Cassandra service is ${SVC_STATE}"
    SERVICE_DOWN=$(( SERVICE_DOWN + 1 ))
    OVERALL=1
    continue
  fi

  # 3. What is this node's status in the ring?
  NODE_STATUS=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${NODE}" \
    "nodetool status 2>/dev/null | awk '/^(U|D)(N|L|J|M).*${NODE}/{print \$1}'" || echo "UNKNOWN")

  if [ "${NODE_STATUS}" = "UN" ]; then
    ok "  ${NODE} — UN (Up/Normal)"
  else
    fail "  ${NODE} — status is '${NODE_STATUS:-UNKNOWN}' (expected UN)"
    NOT_UN=$(( NOT_UN + 1 ))
    OVERALL=1
  fi

  echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════"
HEALTHY=$(( ${#NODES[@]} - UNREACHABLE - SERVICE_DOWN - NOT_UN ))

if [ "${OVERALL}" -eq 0 ]; then
  ok "Cluster status: ALL NODES HEALTHY (${#NODES[@]}/${#NODES[@]} nodes UN)"
else
  if [ "${UNREACHABLE}" -gt 0 ]; then
    fail "${UNREACHABLE} node(s) UNREACHABLE"
  fi
  if [ "${SERVICE_DOWN}" -gt 0 ]; then
    fail "${SERVICE_DOWN} node(s) have Cassandra service NOT RUNNING"
  fi
  if [ "${NOT_UN}" -gt 0 ]; then
    fail "${NOT_UN} node(s) NOT in UN state"
  fi
  warn "Cluster status: ${HEALTHY}/${#NODES[@]} nodes healthy"
fi
echo "════════════════════════════════════════════════════════════"
echo ""

exit "${OVERALL}"
