#!/usr/bin/env bash
audit_3_6() {
    local CHECK_ID="3.6"
    local TITLE="Data Center Authorizations activated"
    local SECTION="3 Access Control"
    local EXPECTED="CassandraNetworkAuthorizer"
    local REMEDIATION="Set network_authorizer in cassandra.yaml."
    local SEVERITY="MEDIUM"

    local current_val
    current_val=$(grep -i "^network_authorizer:" /etc/cassandra/cassandra.yaml 2>/dev/null | awk '{print $2}' || echo "Unknown/File Missing")
    [[ -z "$current_val" ]] && current_val="Not configured"

    json_result "$CHECK_ID" "$TITLE" "MANUAL" "$SEVERITY" "$current_val" "$EXPECTED" "$REMEDIATION" "$SECTION"
}
harden_3_6() { log_warn "Manual action: Edit cassandra.yaml network_authorizer."; }
verify_3_6() { audit_3_6; }
