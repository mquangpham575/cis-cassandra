#!/usr/bin/env bash
# cis-tool.sh - Member 2 Unified Dynamic Tool (v3.0 - Dashboard UI)
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load Core Library
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "[ERROR] Missing library: $SCRIPT_DIR/lib/common.sh" >&2
    exit 1
fi

usage() {
    echo "Usage: sudo ./scripts/cis-tool.sh [audit|harden|verify] [1|2|3|4|5|os|all]"
    echo "  Example 1: sudo ./scripts/cis-tool.sh audit 3"
    echo "  Example 2: sudo ./scripts/cis-tool.sh verify (Quét toàn cụm)"
}

# =========================================================================
# UI DASHBOARD FUNCTION
# =========================================================================
print_dashboard() {
    local json_file=$1
    local node_name=$2
    
    echo ""
    echo -e "\e[36m>>> NODE: $node_name\e[0m"
    echo "--------------------------------------------------------------------------------------"
    printf "%-5s %-70s %s\n" "ID" "RECOMMENDATION TITLE" "STATUS"
    echo "--------------------------------------------------------------------------------------"
    
    if [ ! -f "$json_file" ]; then
        echo -e "\e[31m[ERROR] Report not found for $node_name\e[0m\n"
        return
    fi

    grep '"check_id"' "$json_file" | while read -r line; do
        local id=$(echo "$line" | grep -o '"check_id":"[^"]*"' | cut -d'"' -f4)
        local title=$(echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        local status=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        
        local color_reset="\e[0m"
        local color_green="\e[32m"
        local color_red="\e[31m"
        local color_yellow="\e[33m"
        
        local colored_status
        if [[ "$status" == "PASS" ]]; then
            colored_status="${color_green}[PASS]${color_reset}"
        elif [[ "$status" == "FAIL" || "$status" == "ERROR" ]]; then
            colored_status="${color_red}[FAIL]${color_reset}"
        else
            colored_status="${color_yellow}[WARN]${color_reset}" # MANUAL check
        fi
        
        title=${title:0:68}
        
        printf "%-5s %-70s %b\n" "$id" "$title" "$colored_status"
    done
    echo ""
}

# =========================================================================
# CORE FUNCTIONS
# =========================================================================
run_task() {
    local mode=$1
    local target=$2
    local TMPFILE=$(mktemp)
    trap "rm -f $TMPFILE" EXIT

    local DIRS_TO_SCAN=()

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

    if [[ "$mode" == "audit" ]]; then
        local ip=$(hostname -I | awk '{print $1}' || echo "localhost")
        local REPORT_PATH="$SCRIPT_DIR/reports/report.json"
        
        log_info "Generating Consolidated JSON Report..."
        mkdir -p "$SCRIPT_DIR/reports"
        build_report "$ip" "$TMPFILE" > "$REPORT_PATH"
        
        log_ok "Report saved at: $REPORT_PATH"
        
        print_dashboard "$REPORT_PATH" "Local Node ($ip)"
        
        if grep -qE '"status":"(FAIL|ERROR)"' "$REPORT_PATH"; then
            log_warn "Audit FAILED. Please review findings before merging."
            exit 1
        fi
        log_ok "Audit PASSED successfully."
    fi
}

run_verify() {
    clear
    echo -e "\e[36m======================================================================\e[0m"
    echo -e "\e[36m  CIS CASSANDRA 4.0 BENCHMARK VERIFICATION REPORT\e[0m"
    echo -e "\e[36m  Generated: $(date +'%Y-%m-%d %H:%M:%S')\e[0m"
    echo -e "\e[36m======================================================================\e[0m\n"
    
    echo -e "\e[33m[INFO] Requesting audit data from all nodes in parallel via Azure...\e[0m"
    echo -e "\e[33m[INFO] This usually takes 15-30 seconds. Please wait.\e[0m\n"

    sudo "$SCRIPT_DIR/cis-tool.sh" audit all > /dev/null 2>&1
    print_dashboard "$SCRIPT_DIR/reports/report.json" "node1 (cis-cassandra-node1)"

    # Uncomment when Node 2 and Node 3 are ready with SSH keys
    # echo -e "\e[33m[INFO] Fetching from Node 2 (10.0.1.12)...\e[0m"
    # ssh cassandra@10.0.1.12 "sudo ~/cis-cassandra/scripts/cis-tool.sh audit all" > /dev/null 2>&1
    # scp cassandra@10.0.1.12:~/cis-cassandra/scripts/reports/report.json "$SCRIPT_DIR/reports/node2.json" > /dev/null 2>&1
    # print_dashboard "$SCRIPT_DIR/reports/node2.json" "node2 (cis-cassandra-node2)"

    # echo -e "\e[33m[INFO] Fetching from Node 3 (10.0.1.13)...\e[0m"
    # ssh cassandra@10.0.1.13 "sudo ~/cis-cassandra/scripts/cis-tool.sh audit all" > /dev/null 2>&1
    # scp cassandra@10.0.1.13:~/cis-cassandra/scripts/reports/report.json "$SCRIPT_DIR/reports/node3.json" > /dev/null 2>&1
    # print_dashboard "$SCRIPT_DIR/reports/node3.json" "node3 (cis-cassandra-node3)"
}

CMD=${1:-}
TARGET=${2:-}

case "$CMD" in
    audit)  
        [[ -z "$TARGET" ]] && { usage; exit 1; }
        run_task "audit" "$TARGET" 
        ;;
    harden) 
        [[ -z "$TARGET" ]] && { usage; exit 1; }
        run_task "harden" "$TARGET" 
        ;;
    verify) 
        run_verify 
        ;;
    *)      
        usage; exit 1 
        ;;
esac
