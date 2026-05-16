#!/usr/bin/env bash
CASSANDRA_YAML="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
LOGBACK_XML="${LOGBACK_XML:-/etc/cassandra/logback.xml}"
CASSANDRA_ENV="${CASSANDRA_ENV:-/etc/cassandra/cassandra-env.sh}"
NODE_IPS=("10.0.1.11" "10.0.1.12" "10.0.1.13")
SSH_KEY="${CIS_SSH_KEY:-$HOME/.ssh/cis_key}"
SSH_USER="${CIS_SSH_USER:-cassandra}"

NC='\033[0m'
if [ -t 1 ]; then GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; else GREEN=''; RED=''; YELLOW=''; CYAN=''; BLUE=''; NC=''; fi

# Các hàm ghi log chuyên nghiệp (Professional Logging)
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"; echo -e "${CYAN}┃ $* ${NC}"; echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }
log_warn()   { echo -e "${YELLOW}[!] FAIL:${NC} $*"; }
log_err()    { echo -e "${RED}[✘] ERR :${NC} $*"; }
log_manual() { echo -e "${CYAN}[?] MANUAL:${NC} $*"; }

# Hàm kiểm tra quyền Root
check_root() {
    if [[ "$CIS_MOCK" == "1" ]]; then
        return 0
    fi
    if [ "$EUID" -ne 0 ]; then
        log_err "Please run using root (sudo)."
        exit 1
    fi
}

# Hàm xuất JSON cho Backend (Member 3)
json_result() {
  local check_id="$1" title="$2" status="$3" severity="$4" current_val="$5" expected_val="$6" remediation="$7" section="$8"
  
  # Strip ANSI color codes for JSON output to prevent dashboard parsing errors
  local clean_val=$(echo "$current_val" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g')
  local clean_exp=$(echo "$expected_val" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g')
  local clean_rem=$(echo "$remediation" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g')

  printf '{"check_id":"%s","title":"%s","status":"%s","severity":"%s","current_value":"%s","expected_value":"%s","remediation":"%s","section":"%s","node":"%s","timestamp":"%s"}\n' \
    "$check_id" "$title" "$status" "$severity" "$clean_val" "$clean_exp" "$clean_rem" "$section" "$(hostname -I | awk '{print $1}')" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
}

# Các hàm thao tác với Cassandra
cassandra_yaml_get() { grep "^$1:" "$CASSANDRA_YAML" | awk '{print $2}' | tr -d '\r'; }
cassandra_yaml_set() { sed -i "s/^$1:.*/$1: $2/" "$CASSANDRA_YAML"; }
# 3. CQL Query Execution Tool
# 3. CQL Query Execution Tool
cqlsh_query() {
    local query="$1"
    local creds_file="/etc/cassandra/.db_creds"
    
    if [[ -f "$creds_file" ]]; then
        source "$creds_file"
        sudo CQLSH_PYTHON=/usr/bin/python3.11 /opt/cassandra/bin/cqlsh --ssl -u "$CASSANDRA_USER" -p "$CASSANDRA_PASS" -e "${query}" | grep -v '^-' | grep -v '^$'
    else
        sudo CQLSH_PYTHON=/usr/bin/python3.11 /opt/cassandra/bin/cqlsh --ssl -e "${query}" | grep -v '^-' | grep -v '^$'
    fi
}

# Hàm gom Report cuối cùng
build_report() {
  local node="$1" checks_file="$2"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local total=$(grep -c '"check_id":' "$checks_file" 2>/dev/null || echo 0)
  local passed=$(grep -c '"status":"PASS"' "$checks_file" 2>/dev/null || echo 0)
  local failed=$(grep -c '"status":"FAIL"' "$checks_file" 2>/dev/null || echo 0)
  local manual=$(grep -c '"status":"MANUAL"' "$checks_file" 2>/dev/null || echo 0)
  
  printf '{\n  "node": "%s",\n  "timestamp": "%s",\n  "score": {\n    "total": %s,\n    "passed": %s,\n    "failed": %s,\n    "manual": %s\n  },\n  "checks": [\n' "$node" "$timestamp" "$total" "$passed" "$failed" "$manual"
  
  local first=true
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if $first; then printf '    %s' "$line"; first=false; else printf ',\n    %s' "$line"; fi
  done < "$checks_file"
  printf '\n  ]\n}\n'
}

# Hàm gom Report CSV
build_csv_report() {
  local checks_file="$1"
  echo "Check ID,Section,Title,Status,Severity,Current Value,Expected Value,Node,Timestamp"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Extract values using sed (simpler for raw CSV generation)
    local id=$(echo "$line" | sed -n 's/.*"check_id":"\([^"]*\)".*/\1/p')
    local section=$(echo "$line" | sed -n 's/.*"section":"\([^"]*\)".*/\1/p')
    local title=$(echo "$line" | sed -n 's/.*"title":"\([^"]*\)".*/\1/p')
    local status=$(echo "$line" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
    local severity=$(echo "$line" | sed -n 's/.*"severity":"\([^"]*\)".*/\1/p')
    local current=$(echo "$line" | sed -n 's/.*"current_value":"\([^"]*\)".*/\1/p')
    local expected=$(echo "$line" | sed -n 's/.*"expected_value":"\([^"]*\)".*/\1/p')
    local node=$(echo "$line" | sed -n 's/.*"node":"\([^"]*\)".*/\1/p')
    local ts=$(echo "$line" | sed -n 's/.*"timestamp":"\([^"]*\)".*/\1/p')
    
    printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' "$id" "$section" "$title" "$status" "$severity" "$current" "$expected" "$node" "$ts"
  done < "$checks_file"
}
