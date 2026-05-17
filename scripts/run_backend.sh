#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
VENV_DIR="$BACKEND_DIR/.venv"

log() {
  echo "[backend] $*"
}

need_sudo() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "This script needs sudo/root because it installs system packages. Re-run with: sudo $0"
    exit 1
  fi
}

install_prereqs() {
  export DEBIAN_FRONTEND=noninteractive
  log "Installing system prerequisites..."
  apt-get update
  apt-get install -y python3 python3-venv python3-pip build-essential libffi-dev libssl-dev
}

setup_venv() {
  log "Creating Python virtual environment at $VENV_DIR"
  python3 -m venv "$VENV_DIR"
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  log "Upgrading pip tooling"
  python -m pip install --upgrade pip setuptools wheel
  log "Installing backend requirements"
  pip install -r "$BACKEND_DIR/requirements.txt"
}

run_backend() {
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  export CIS_SSH_KEY="${CIS_SSH_KEY:-/home/cassandra/.ssh/cis_key}"
  export CIS_SSH_USER="${CIS_SSH_USER:-cassandra}"
  export CIS_TOOL_PATH="${CIS_TOOL_PATH:-/home/cassandra/cis-cassandra/scripts/cis-tool.sh}"
  export PYTHONPATH="$BACKEND_DIR"
  export API_HOST="${API_HOST:-0.0.0.0}"
  export API_PORT="${API_PORT:-8000}"
  log "Starting FastAPI backend on ${API_HOST}:${API_PORT}"
  cd "$BACKEND_DIR"
  exec uvicorn main:app --host "$API_HOST" --port "$API_PORT"
}

main() {
  need_sudo
  install_prereqs
  setup_venv
  run_backend
}

main "$@"