#!/usr/bin/env bash
audit_3_2() {
    local CHECK_ID="3.2"
    local TITLE="Default password changed for cassandra"
    local SECTION="3 Access Control"
    local EXPECTED="Login failed with default credentials"
    local REMEDIATION="Alter cassandra role with new password."
    local SEVERITY="CRITICAL"

    local current_val
    # If login succeeds with default pass, it's a FAIL.
    if cqlsh -u cassandra -p cassandra -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; then
        current_val="Login successful with default password"
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        current_val="Login rejected or DB unreachable"
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_3_2() { log_warn "Manual action: Run ALTER ROLE cassandra WITH PASSWORD..."; }
verify_3_2() { audit_3_2; }
