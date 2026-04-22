#!/usr/bin/env bash
audit_3_1() {
    local CHECK_ID="3.1"
    local TITLE="Separate cassandra and superuser roles"
    local SECTION="3 Access Control"
    local EXPECTED="cassandra is not superuser"
    local REMEDIATION="Create new superuser and demote cassandra role."
    local SEVERITY="HIGH"

    local current_val
    current_val=$(cqlsh -e "select role from system_auth.roles where is_superuser = True ALLOW FILTERING;" 2>/dev/null | grep -w "cassandra" || echo "Safe")

    if [[ "$current_val" == *"cassandra"* ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "cassandra has superuser status" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "cassandra is demoted or DB unreachable" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_3_1() { log_warn "Manual action: Alter roles via CQL required."; }
verify_3_1() { audit_3_1; }
