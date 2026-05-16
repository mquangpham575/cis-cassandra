#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define logging internally for robustness
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"; echo -e "┃ $* "; echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }
log_warn()   { echo -e "${YELLOW}[!] FAIL:${NC} $*"; }
log_manual() { echo -e "${CYAN}[?] MANUAL:${NC} $*"; }

if [[ -f "$DIR/scripts/lib/common.sh" ]]; then source "$DIR/scripts/lib/common.sh"; fi

MODE=""
SECTION=""
TARGET="local"

while [[ $# -gt 0 ]]; do
  case $1 in
    audit) MODE="audit"; shift ;;
    harden) MODE="harden"; shift ;;
    cluster) TARGET="cluster"; shift ;;
    --section) SECTION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# --- CLUSTER MODE ---
if [[ "$TARGET" == "cluster" ]]; then
    COMBINED_FILE="$DIR/scripts/reports/cluster_results.json"
    > "$COMBINED_FILE"
    for IP in "${NODE_IPS[@]}"; do
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "sudo bash ~/cis-tool/cis-tool.sh $MODE ${SECTION:+--section $SECTION}" | while read -r line; do
            if [[ "$line" == "{"* ]]; then echo "$line" >> "$COMBINED_FILE"; else echo -e "${CYAN}[$IP]${NC} $line"; fi
        done
    done
    exit 0
fi

# --- LOCAL MODE ---
RESULTS_FILE="/tmp/cis_results.json"
> "$RESULTS_FILE"

cd "$DIR"
SEARCH_DIR="scripts/sections"
if [[ -n "$SECTION" ]]; then
    SEARCH_DIR=$(find scripts/sections -maxdepth 1 -type d -name "*${SECTION}*" | head -n 1)
fi

for script in $(find "$SEARCH_DIR" -name "check_*.sh" | sort); do
    source "$script"
    check_num=$(basename "$script" .sh | sed 's/check_//')
    audit_json=$(audit_${check_num} 2>/dev/null)
    
    title=$(echo "$audit_json" | grep -oP '"title":"\K[^"]+')
    severity=$(echo "$audit_json" | grep -oP '"severity":"\K[^"]+')
    status=$(echo "$audit_json" | grep -oP '"status":"\K[^"]+')
    current_val=$(echo "$audit_json" | grep -oP '"current_value":"\K[^"]+')
    remediation=$(echo "$audit_json" | grep -oP '"remediation":"\K[^"]+')
    
    if [[ "$MODE" == "audit" ]]; then
        echo -e "\n${BLUE}◈ ID ${check_num//_/./}:${NC} ${title}"
        echo -e "  └─ Severity: ${severity}"
        echo -e "  └─ Evidence: ${current_val}"
        if [[ "$status" == "PASS" ]]; then log_ok "Hạng mục này đạt yêu cầu."; elif [[ "$status" == "MANUAL" ]]; then log_manual "Cần kiểm tra thủ công. Gợi ý: ${remediation}"; else log_warn "Vi phạm an ninh detected!"; echo -e "     ${YELLOW}👉 FIX:${NC} ${remediation}"; fi
        echo "$audit_json" >> "$RESULTS_FILE"
    elif [[ "$MODE" == "harden" ]]; then
        harden_${check_num}
    fi
done

if [[ "$MODE" == "audit" ]]; then
    REPORT_PATH="$DIR/scripts/reports/report.json"
    log_info "Đang tổng hợp Report..."
    build_report "$(hostname -I | awk '{print $1}')" "$RESULTS_FILE" > "$REPORT_PATH"
    log_ok "File report được lưu tại: $REPORT_PATH"
    cat "$REPORT_PATH"
    
    if [[ $FAIL_COUNT -gt 0 ]]; then
        log_warn "Có $FAIL_COUNT check FAIL. Exit code 1."
        exit 1
    else
        log_ok "Tất cả PASS. Exit code 0."
        exit 0
    fi
fi
if [[ "$MODE" == "audit" && -z "$NO_JSON" ]]; then cat "$RESULTS_FILE"; fi
