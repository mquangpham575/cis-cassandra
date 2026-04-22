#!/usr/bin/env bash
# Audit: Restrict SSH Root Login to secure the host
audit_os_3() {
    local CHECK_ID="OS.3"
    local TITLE="Disable SSH Root Login"
    local SECTION="OS Custom Checks"
    local EXPECTED="PermitRootLogin no"
    local REMEDIATION="Set PermitRootLogin no in /etc/ssh/sshd_config"
    local SEVERITY="CRITICAL"

    local current_val=$(sshd -T 2>/dev/null | grep -i "^permitrootlogin" | awk '{print $2}')
    [[ -z "$current_val" ]] && current_val="Unknown"

    if [[ "${current_val,,}" == "no" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
