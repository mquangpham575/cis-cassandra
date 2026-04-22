#!/usr/bin/env bash
# Audit: Ensure swap is disabled for Cassandra performance
audit_os_1() {
    local CHECK_ID="OS.1"
    local TITLE="Disable SWAP memory"
    local SECTION="OS Custom Checks"
    local EXPECTED="Swap is 0"
    local REMEDIATION="Run 'swapoff -a' and remove from /etc/fstab"
    local SEVERITY="CRITICAL"

    local swap_total=$(free -m | awk '/^Swap:/ {print $2}')
    if [[ "$swap_total" == "0" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "Swap: $swap_total MB" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "Swap: $swap_total MB" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
