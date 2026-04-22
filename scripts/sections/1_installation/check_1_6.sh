#!/usr/bin/env bash

audit_1_6() {
    local CHECK_ID="1.6"
    local TITLE="Clocks are synchronized"
    local SECTION="1 Installation and Updates"
    local EXPECTED="NTP Active"
    local REMEDIATION="Install and start NTP/chrony on every node."
    local SEVERITY="HIGH"

    local current_val
    if timedatectl status 2>/dev/null | grep -q "systemd-timesyncd.service active" || timedatectl status 2>/dev/null | grep -qi "NTP service: active"; then
        current_val="NTP is Active"
    elif ps -aef | grep -E 'ntpd|chronyd' | grep -v grep > /dev/null; then
        current_val="NTP/Chrony process running"
    else
        current_val="NTP not found or inactive"
    fi

    json_result "$CHECK_ID" "$TITLE" "MANUAL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}

harden_1_6() {
    log_warn "Manual Check: Install chrony or ntp and start the service."
}

verify_1_6() {
    audit_1_6
}
