#!/usr/bin/env bash
# Audit: Ensure sufficient file descriptors for Cassandra
audit_os_5() {
    local CHECK_ID="OS.5"
    local TITLE="Max Open Files Limit"
    local SECTION="OS Custom Checks"
    local EXPECTED=">= 100000"
    local REMEDIATION="Update nofile limits in /etc/security/limits.conf"
    local SEVERITY="HIGH"

    local current_val=$(ulimit -n 2>/dev/null || echo "Unknown")
    
    if [[ "$current_val" =~ ^[0-9]+$ ]] && [ "$current_val" -ge 100000 ]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
