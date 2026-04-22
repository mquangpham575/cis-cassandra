#!/usr/bin/env bash
audit_5_1() {
    local CHECK_ID="5.1"
    local TITLE="Inter-node Encryption (TLS)"
    local SECTION="5 Encryption"
    local EXPECTED="all, dc, or rack"
    local REMEDIATION="Set internode_encryption in cassandra.yaml."
    local SEVERITY="HIGH"

    local current_val
    current_val=$(grep -i "^internode_encryption:" /etc/cassandra/cassandra.yaml 2>/dev/null | awk '{print $2}' | tr -d '\r')
    [[ -z "$current_val" ]] && current_val="none"

    if [[ "$current_val" == "all" || "$current_val" == "dc" || "$current_val" == "rack" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_5_1() { log_warn "Manual action: Setup keystore/truststore and configure internode TLS."; }
verify_5_1() { audit_5_1; }
