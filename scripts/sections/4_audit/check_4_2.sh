#!/usr/bin/env bash
audit_4_2() {
    local CHECK_ID="4.2"
    local TITLE="Auditing is enabled"
    local SECTION="4 Auditing and Logging"
    local EXPECTED="enabled: true"
    local REMEDIATION="Set enabled: true under audit_logging_options in cassandra.yaml."
    local SEVERITY="MEDIUM"

    local current_val
    current_val=$(grep -A2 -i "^audit_logging_options:" /etc/cassandra/cassandra.yaml 2>/dev/null | grep "enabled:" | head -n 1 | awk '{print $2}' | tr -d '\r' | tr -d ' ')
    
    local status="FAIL"
    [[ "$current_val" == "true" ]] && status="PASS"

    json_result "$CHECK_ID" "$TITLE" "$status" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}
harden_4_2() {
    # Check if audit_logging_options exists
    if grep -q "^audit_logging_options:" /etc/cassandra/cassandra.yaml; then
        # Use sed to find the next line with 'enabled:' and set it to true
        # This is a bit tricky with multiline, but we can try a simple sed pattern
        sed -i '/^audit_logging_options:/,/enabled:/ s/enabled: false/enabled: true/' /etc/cassandra/cassandra.yaml
        log_info "4.2 Hardened: Enabled audit_logging_options in cassandra.yaml"
    else
        # Append it if missing
        cat >> /etc/cassandra/cassandra.yaml <<EOF

audit_logging_options:
    enabled: true
    logger: BinAuditLogger
EOF
        log_info "4.2 Hardened: Added audit_logging_options to cassandra.yaml"
    fi
}
verify_4_2() { audit_4_2; }
