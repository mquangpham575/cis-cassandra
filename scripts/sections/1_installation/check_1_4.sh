#!/usr/bin/env bash

audit_1_4() {
    local CHECK_ID="1.4"
    local TITLE="Latest Cassandra version installed"
    local SECTION="1 Installation and Updates"
    local EXPECTED="Cassandra 4.0.x"
    local REMEDIATION="Upgrade Cassandra to the latest stable 4.0.x release."
    local SEVERITY="HIGH"

    local current_val
    current_val=$(cassandra -v 2>/dev/null | head -n 1)
    [[ -z "$current_val" ]] && current_val="Not Installed"

    if [[ "$current_val" == 4.0.* ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}

harden_1_4() {
    log_warn "Manual action: Upgrade Cassandra cluster manually."
}

verify_1_4() {
    audit_1_4
}
