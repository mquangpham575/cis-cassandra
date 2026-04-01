#!/usr/bin/env bash
# cis-tool.sh — Unified CIS Cassandra 4.0 Benchmark CLI
# Usage: sudo cis-tool.sh <command> [target] [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Source all lib files (audit + harden + demo + cluster)
for f in "$SCRIPT_DIR/lib/"*.sh; do source "$f"; done

usage() {
  cat <<EOF
Usage: cis-tool.sh <command> [target] [options]

COMMANDS
  audit   [all|1|2|3|4|5|<check-id>]   Run CIS audit checks (outputs JSON)
  harden  [all|1|2|3|4|5|<check-id>]   Apply CIS hardening
  report  [--format json|text]          Full compliance report
  demo    [reset|attack]                Demo helpers
  cluster [deploy|restart|status]       Cluster management

OPTIONS
  --node <ip>     Target a specific remote node via SSH
  --all-nodes     Run on all configured nodes (${NODE_IPS[*]})
  --dry-run       Show what would change, without applying

EXAMPLES
  cis-tool.sh audit all
  cis-tool.sh audit all --all-nodes
  cis-tool.sh audit 2.1
  cis-tool.sh harden all --all-nodes
  cis-tool.sh harden 5.1 --node 192.168.56.13
  cis-tool.sh demo reset --all-nodes
  cis-tool.sh demo attack
  cis-tool.sh cluster status
EOF
}

# Parse flags
DRY_RUN=false
TARGET_NODE=""
ALL_NODES=false

parse_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)    DRY_RUN=true; shift ;;
      --node)       TARGET_NODE="$2"; shift 2 ;;
      --all-nodes)  ALL_NODES=true; shift ;;
      *)            shift ;;
    esac
  done
}

run_on_node() {
  local node="$1" cmd="$2"
  if [ "$node" = "localhost" ]; then
    bash -c "$cmd"
  else
    ssh_run "$node" "sudo $cmd"
  fi
}

run_on_targets() {
  local cmd="$1"
  if $ALL_NODES; then
    for node in "${NODE_IPS[@]}"; do
      echo "--- Node: $node ---" >&2
      run_on_node "$node" "$cmd"
    done
  elif [ -n "$TARGET_NODE" ]; then
    run_on_node "$TARGET_NODE" "$cmd"
  else
    bash -c "$cmd"
  fi
}

cmd_audit() {
  parse_flags "$@"
  local target="${1:-all}"
  local TMPFILE
  TMPFILE=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f $TMPFILE" EXIT

  case "$target" in
    all)
      check_section_1 >> "$TMPFILE"
      check_section_2 >> "$TMPFILE"
      check_section_3 >> "$TMPFILE"
      check_section_4 >> "$TMPFILE"
      check_section_5 >> "$TMPFILE"
      ;;
    1) check_section_1 >> "$TMPFILE" ;;
    2) check_section_2 >> "$TMPFILE" ;;
    3) check_section_3 >> "$TMPFILE" ;;
    4) check_section_4 >> "$TMPFILE" ;;
    5) check_section_5 >> "$TMPFILE" ;;
    *.*)
      fn="check_$(echo "$target" | tr '.' '_')"
      if ! declare -f "$fn" > /dev/null 2>&1; then
        error "No audit function for check: $target (expected: $fn)"; exit 1
      fi
      "$fn" >> "$TMPFILE"
      ;;
    *) error "Unknown audit target: $target"; usage; exit 1 ;;
  esac

  local node_ip
  node_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  build_report "$node_ip" "$TMPFILE"
}

cmd_harden() {
  parse_flags "$@"
  local target="${1:-all}"
  case "$target" in
    all)
      harden_section_1; harden_section_2; harden_section_3
      harden_section_4; harden_section_5
      ;;
    1) harden_section_1 ;;
    2) harden_section_2 ;;
    3) harden_section_3 ;;
    4) harden_section_4 ;;
    5) harden_section_5 ;;
    *.*)
      fn="apply_$(echo "$target" | tr '.' '_')"
      if ! declare -f "$fn" > /dev/null 2>&1; then
        error "No harden function for check: $target (expected: $fn)"; exit 1
      fi
      "$fn"
      ;;
    *) error "Unknown harden target: $target"; usage; exit 1 ;;
  esac
}

cmd_report() {
  parse_flags "$@"
  cmd_audit all
}

cmd_demo() {
  local subcmd="${1:-}"
  parse_flags "$@"
  case "$subcmd" in
    reset)  demo_reset ;;
    attack) demo_attack ;;
    *) error "Usage: cis-tool.sh demo [reset|attack]"; exit 1 ;;
  esac
}

cmd_cluster() {
  local subcmd="${1:-}"
  case "$subcmd" in
    status)  cluster_status ;;
    restart) cluster_rolling_restart ;;
    deploy)  cluster_deploy ;;
    *) error "Usage: cis-tool.sh cluster [status|restart|deploy]"; exit 1 ;;
  esac
}

# Main dispatch
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  audit)   cmd_audit "$@" ;;
  harden)  cmd_harden "$@" ;;
  report)  cmd_report "$@" ;;
  demo)    cmd_demo "$@" ;;
  cluster) cmd_cluster "$@" ;;
  -h|--help|help|"") usage ;;
  *) error "Unknown command: $COMMAND"; usage; exit 1 ;;
esac
