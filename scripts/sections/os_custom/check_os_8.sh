#!/usr/bin/env bash
# Audit: Disable IPv6 to reduce attack surface (if not required)
audit_os_8() {
    local CHECK_ID="OS.8"
    local TITLE="Disable IPv6"
    local SECTION="OS Custom Checks"
    local EXPECTED="1"
    local REMEDIATION="sysctl -w net.ipv6.conf.all.disable_ipv6=1"
    local SEVERITY="LOW"

    local current_val=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "Unknown")
    
    if [[ "$current_val" == "1" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
