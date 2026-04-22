#!/usr/bin/env bash

audit_1_3() {
    local CHECK_ID="1.3"
    local TITLE="Latest Python version installed"
    local SECTION="1 Installation and Updates"
    local EXPECTED="Python 3.x"
    local REMEDIATION="Install the latest version of Python 3."
    local SEVERITY="MEDIUM"

    local current_val
    current_val=$(python3 --version 2>&1 | awk '{print $2}')
    [[ -z "$current_val" ]] && current_val="Not Installed"

    if [[ "$current_val" == 3.* ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}

harden_1_3() {
    log_warn "Manual action: Install Python 3."
}

verify_1_3() {
    audit_1_3
}
