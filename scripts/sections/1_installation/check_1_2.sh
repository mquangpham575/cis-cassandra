#!/usr/bin/env bash

audit_1_2() {
    local CHECK_ID="1.2"
    local TITLE="Latest Java version installed"
    local SECTION="1 Installation and Updates"
    local EXPECTED="Java 1.8 or 11"
    local REMEDIATION="Install OpenJDK 8 or 11."
    local SEVERITY="MEDIUM"

    local current_val
    current_val=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1,2 | tr -d '[:space:]')
    [[ -z "$current_val" ]] && current_val="Not Installed"

    # Sử dụng Regex (=~) để match bắt đầu bằng 1.8 hoặc 11
    if [[ "$current_val" =~ ^1\.8 || "$current_val" =~ ^11 ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}

harden_1_2() {
    log_warn "Manual action: Install Java 11 or 1.8."
}

verify_1_2() {
    audit_1_2
}
