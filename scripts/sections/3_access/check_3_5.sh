#!/usr/bin/env bash
audit_3_5() {
    local CHECK_ID="3.5"
    local TITLE="Listen on authorized interfaces"
    local SECTION="3 Access Control"
    local EXPECTED="Specific IP / Not 0.0.0.0"
    local REMEDIATION="Set listen_address to specific interface."
    local SEVERITY="HIGH"

    local current_val
    current_val=$(grep -i "^listen_address:" /etc/cassandra/cassandra.yaml 2>/dev/null | awk '{print $2}' || echo "Unknown/File Missing")
    [[ -z "$current_val" ]] && current_val="Not configured"

    json_result "$CHECK_ID" "$TITLE" "MANUAL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}
harden_3_5() { log_warn "Manual action: Edit cassandra.yaml listen_address."; }
verify_3_5() { audit_3_5; }
