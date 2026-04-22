#!/usr/bin/env bash
audit_5_2() {
    local CHECK_ID="5.2"
    local TITLE="Client Encryption (TLS)"
    local SECTION="5 Encryption"
    local EXPECTED="enabled: true"
    local REMEDIATION="Set enabled to true under client_encryption_options in cassandra.yaml."
    local SEVERITY="HIGH"

    local current_val
    current_val=$(grep -A5 -i "^client_encryption_options:" /etc/cassandra/cassandra.yaml 2>/dev/null | grep "enabled:" | head -n 1 | awk '{print $2}' | tr -d '\r')
    [[ -z "$current_val" ]] && current_val="false"

    if [[ "$current_val" == "true" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_5_2() { log_warn "Manual action: Setup keystore/truststore and configure client TLS."; }
verify_5_2() { audit_5_2; }
