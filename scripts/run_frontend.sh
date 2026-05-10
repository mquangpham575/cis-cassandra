#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"

log() {
  echo "[frontend] $*"
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
  apt-get install -y curl ca-certificates gnupg

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    log "Installing Node.js 20 from NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
}

install_node_deps() {
  log "Installing frontend npm dependencies"
  cd "$FRONTEND_DIR"
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
}

run_frontend() {
  cd "$FRONTEND_DIR"
  export VITE_API_URL="${VITE_API_URL:-http://127.0.0.1:8000}"
  export VITE_API_SECRET_KEY="${VITE_API_SECRET_KEY:-change-me-in-production}"
  log "Starting Vite dev server with API proxy target ${VITE_API_URL}"
  exec npm run dev -- --host 0.0.0.0
}

main() {
  need_sudo
  install_prereqs
  install_node_deps
  run_frontend
}

main "$@"