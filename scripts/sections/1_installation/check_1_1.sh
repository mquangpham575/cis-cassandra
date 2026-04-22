#!/usr/bin/env bash

audit_1_1() {
    # Khai bao local ben trong ham de tranh ghi de bien
    local CHECK_ID="1.1"
    local TITLE="Separate user and group for Cassandra"
    local SECTION="1 Installation and Updates"
    local EXPECTED="cassandra user and group exist"
    local REMEDIATION="Run 'groupadd cassandra' and 'useradd -m -g cassandra cassandra' manually."
    local SEVERITY="HIGH"

    # Logic kiem tra
    local group_info
    group_info=$(getent group cassandra || echo "No group")
    local user_info
    user_info=$(getent passwd cassandra || echo "No user")
    local current_val="Group: ${group_info} | User: ${user_info}"

    # Day la Manual check nen status luon la MANUAL
    json_result "$CHECK_ID" "$TITLE" "MANUAL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}

harden_1_1() {
    log_warn "Manual check. Please create user/group manually if missing."
}

verify_1_1() {
    audit_1_1
}
