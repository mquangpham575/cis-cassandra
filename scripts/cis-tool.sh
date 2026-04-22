#!/usr/bin/env bash
# cis-tool.sh - Member 2 Unified Dynamic Tool (v2.1 - With Detail View)
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load Core Library [cite: 978, 979]
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "[ERROR] Missing library: $SCRIPT_DIR/lib/common.sh" >&2
    exit 1
fi

usage() {
    echo "Usage: sudo ./scripts/cis-tool.sh audit [1|2|3|4|5|os|all]"
}

run_task() {
    local mode=$1
    local target=$2
    local TMPFILE=$(mktemp)
    trap "rm -f $TMPFILE" EXIT

    local DIRS_TO_SCAN=()

    # Determine which sections to audit [cite: 1030]
    if [[ "$target" == "all" ]]; then
        for d in "$SCRIPT_DIR/sections"/*/; do
            [[ -d "$d" ]] && DIRS_TO_SCAN+=("$d")
        done
    elif [[ "$target" == "os" || "$target" == "os_custom" ]]; then
        DIRS_TO_SCAN+=("$SCRIPT_DIR/sections/os_custom/")
    else
        local found=$(find "$SCRIPT_DIR/sections" -maxdepth 1 -type d -name "${target}_*" | head -n 1)
        if [[ -n "$found" ]]; then
            DIRS_TO_SCAN+=("$found/")
        else
            log_err "Section directory not found for: $target"
            exit 1
        fi
    fi

    # Execute checks in found directories [cite: 974, 981]
    for SEARCH_DIR in "${DIRS_TO_SCAN[@]}"; do
        log_info "Scanning section: $(basename "$SEARCH_DIR")"
        
        for script in $(find "$SEARCH_DIR" -name "check_*.sh" | sort); do
            source "$script"
            local check_suffix=$(basename "$script" .sh | sed 's/check_//')
            
            if [[ "$mode" == "audit" ]]; then
                audit_${check_suffix} >> "$TMPFILE"
            elif [[ "$mode" == "harden" ]]; then
                harden_${check_suffix}
            fi
        done
    done

    # Finalize Report [cite: 972, 1027]
    if [[ "$mode" == "audit" ]]; then
        local ip=$(hostname -I | awk '{print $1}' || echo "localhost")
        local REPORT_PATH="$SCRIPT_DIR/reports/report.json"
        
        log_info "Generating Consolidated JSON Report..."
        mkdir -p "$SCRIPT_DIR/reports"
        build_report "$ip" "$TMPFILE" > "$REPORT_PATH"
        
        log_ok "Report saved at: $REPORT_PATH"
        
        # ĐÂY RỒI! In chi tiết ra màn hình cho bạn xem
        cat "$REPORT_PATH"
        
        # Exit codes for CI/CD (Bắt cả FAIL và ERROR)
        if grep -qE '"status":"(FAIL|ERROR)"' "$REPORT_PATH"; then
            log_warn "Audit FAILED. Please review findings before merging."
            exit 1
        fi
        log_ok "Audit PASSED successfully."
    fi
}

CMD=${1:-}
TARGET=${2:-}
[[ -z "$CMD" || -z "$TARGET" ]] && { usage; exit 1; }

case "$CMD" in
    audit)  run_task "audit" "$TARGET" ;;
    harden) run_task "harden" "$TARGET" ;;
    *)      usage; exit 1 ;;
esac
