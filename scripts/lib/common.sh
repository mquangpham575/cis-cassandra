#!/usr/bin/env bash
# common.sh — shared helpers for cis-tool.sh

CASSANDRA_YAML="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
LOGBACK_XML="${LOGBACK_XML:-/etc/cassandra/logback.xml}"
CASSANDRA_ENV="${CASSANDRA_ENV:-/etc/cassandra/cassandra-env.sh}"
NODE_IPS=("4.193.213.85" "4.193.208.18" "4.193.98.211")
SSH_KEY="${CIS_SSH_KEY:-$HOME/.ssh/cis_key}"
SSH_USER="${CIS_SSH_USER:-cassandra}"

# Colors (only if terminal)
NC='\033[0m'
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BLUE='\033[0;34m'
else
  GREEN='' RED='' YELLOW='' CYAN='' BLUE='' NC=''
fi

# Emit one JSON check result line
# Usage: echo_check <id> <title> <status> <type> <section> <evidence> [remediable]
echo_check() {
  local id="$1" title="$2" status="$3" type="$4" section="$5"
  local evidence="${6:-}" remediable="${7:-false}"
  # Sanitize evidence: take first 3 lines, collapse newlines, escape JSON special chars
  evidence=$(printf '%s' "$evidence" | head -3 | tr '\n' ' ' | \
    sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g')
  printf '{"id":"%s","title":"%s","status":"%s","type":"%s","section":"%s","evidence":"%s","remediable":%s}\n' \
    "$id" "$title" "$status" "$type" "$section" "$evidence" "$remediable"
}

# Run a command on a remote node via SSH
# Usage: ssh_run <node_ip> <command>
ssh_run() {
  local node="$1" cmd="$2"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
    "$SSH_USER@$node" "$cmd"
}

# Assemble final JSON report from an array of check JSON lines
# Usage: build_report <node_ip> <check_lines_file>
build_report() {
  local node="$1" checks_file="$2"
  local timestamp total passed failed needs_review automated manual
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  # Count only non-empty lines
  total=$(grep -c '"id":' "$checks_file" 2>/dev/null || true)
  passed=$(grep -c '"status":"PASS"' "$checks_file" 2>/dev/null || true)
  failed=$(grep -c '"status":"FAIL"' "$checks_file" 2>/dev/null || true)
  needs_review=$(grep -c '"status":"NEEDS_REVIEW"' "$checks_file" 2>/dev/null || true)
  # Derive automated/manual from actual check types
  automated=$(grep -c '"type":"automated"' "$checks_file" 2>/dev/null || true)
  manual=$(grep -c '"type":"manual"' "$checks_file" 2>/dev/null || true)

  # Strip leading whitespace from wc output (BSD compat)
  total=${total// /}
  passed=${passed// /}
  failed=${failed// /}
  needs_review=${needs_review// /}
  automated=${automated// /}
  manual=${manual// /}

  printf '{\n'
  printf '  "node": "%s",\n' "$node"
  printf '  "timestamp": "%s",\n' "$timestamp"
  printf '  "score": {\n'
  printf '    "total": %s,\n' "${total:-0}"
  printf '    "automated": %s,\n' "${automated:-0}"
  printf '    "manual": %s,\n' "${manual:-0}"
  printf '    "passed": %s,\n' "${passed:-0}"
  printf '    "failed": %s,\n' "${failed:-0}"
  printf '    "needs_review": %s\n' "${needs_review:-0}"
  printf '  },\n'
  printf '  "checks": [\n'

  # Write each non-empty check line with proper comma separation
  local first=true
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if $first; then
      printf '    %s' "$line"
      first=false
    else
      printf ',\n    %s' "$line"
    fi
  done < "$checks_file"
  printf '\n  ]\n'
  printf '}\n'
}

# Print colored output (only when stdout is a terminal)
info()    { [ -t 1 ] && echo -e "\033[0;34m[INFO]\033[0m $*" || echo "[INFO] $*"; }
success() { [ -t 1 ] && echo -e "\033[0;32m[OK]\033[0m $*"   || echo "[OK] $*"; }
warn()    { [ -t 1 ] && echo -e "\033[1;33m[WARN]\033[0m $*" || echo "[WARN] $*"; }
error()   { [ -t 1 ] && echo -e "\033[0;31m[ERR]\033[0m $*"  || echo "[ERR] $*"; }
