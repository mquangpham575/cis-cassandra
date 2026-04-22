#!/usr/bin/env bash
audit_4_1() {
    local CHECK_ID="4.1"
    local TITLE="Logging is enabled"
    local SECTION="4 Auditing and Logging"
    local EXPECTED="Log level is not OFF"
    local REMEDIATION="Set appropriate logging level in logback.xml."
    local SEVERITY="LOW"

    local current_val
    current_val=$(nodetool getlogginglevels 2>/dev/null | grep -i "OFF" || echo "No OFF found")

    if [[ "$current_val" == *"OFF"* ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "Logging is OFF" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "Logging is Enabled" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}
harden_4_1() { log_warn "Manual action: Adjust logback.xml settings."; }
verify_4_1() { audit_4_1; }
