#!/usr/bin/env bash

audit_5_1() {
    local CHECK_ID="5.1"
    local TITLE="Inter-node Encryption (TLS)"
    local SECTION="5 Encryption"
    local EXPECTED="all or dc"
    local REMEDIATION="Configure PKI and set internode_encryption to all."
    local SEVERITY="HIGH"
    
    # Quét block server_encryption_options
    local val=$(sed -n '/server_encryption_options:/,/^[^ ]/p' /etc/cassandra/cassandra.yaml | grep "internode_encryption:" | head -n 1 | awk '{print $2}')
    
    if [[ "$val" == "all" || "$val" == "dc" ]]; then
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "internode_encryption: $val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    else
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "internode_encryption: $val" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 1
    fi
}

harden_5_1() {
    # KHÔNG sửa file cassandra.yaml để tránh crash. Chỉ in ra cảnh báo yêu cầu làm tay.
    echo -e "${YELLOW}[WARN] $(date -u +%Y-%m-%dT%H:%M:%SZ) - Manual action: 5.1 Internode TLS requires custom PKI/Truststore setup. Skipping auto-remediation to prevent cluster crash.${NC}"
}

verify_5_1() { 
    if ! audit_5_1 >/dev/null 2>&1; then 
        harden_5_1
        audit_5_1 
    else 
        audit_5_1 
    fi 
}
