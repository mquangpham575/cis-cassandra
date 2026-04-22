#!/usr/bin/env bash
# Audit: Ensure strict permissions on core configuration files
audit_os_2() {
    local CHECK_ID="OS.2"
    local TITLE="Strict permissions on cassandra.yaml"
    local SECTION="OS Custom Checks"
    local EXPECTED="600 or 640"
    local REMEDIATION="Run 'chmod 600 /etc/cassandra/cassandra.yaml'"
    local SEVERITY="HIGH"

    local target_file="/etc/cassandra/cassandra.yaml"
    local current_val="File Not Found"
    
    if [[ -f "$target_file" ]]; then
        current_val=$(stat -c "%a" "$target_file")
    fi

    if [[ "$current_val" == "600" ]] || [[ "$current_val" == "640" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
