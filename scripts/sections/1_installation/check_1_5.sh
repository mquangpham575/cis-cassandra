#!/usr/bin/env bash

audit_1_5() {
    local CHECK_ID="1.5"
    local TITLE="Run as non-root user"
    local SECTION="1 Installation and Updates"
    local EXPECTED="non-root"
    local REMEDIATION="Create a dedicated cassandra user and run the service with it."
    local SEVERITY="HIGH"

    local current_user
    current_user=$(ps -eo user,cmd | grep '[c]assandra' | grep java | awk '{print $1}' | head -n 1)

    if [[ -z "$current_user" ]]; then
        json_result "$CHECK_ID" "$TITLE" "ERROR" "$SEVERITY" "Not Running" "$EXPECTED" "Start Cassandra" "$SECTION"
    elif [[ "$current_user" == "root" ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "$current_user" "$EXPECTED" "$REMEDIATION" "$SECTION"
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "$current_user" "$EXPECTED" "$REMEDIATION" "$SECTION"
    fi
}

harden_1_5() {
    log_info "Hardening 1.5: Fixing service owner and permissions..."
    
    # 1. Tạo user/group nếu chưa có
    getent group cassandra > /dev/null || groupadd cassandra
    getent passwd cassandra > /dev/null || useradd -m -s /bin/bash -g cassandra cassandra
    
    # 2. Sửa file khởi động (Fix lỗi cốt lõi khiến nó chạy quyền root)
    if [ -f /etc/init.d/cassandra ]; then
        sudo sed -i 's/CASSANDRA_OWNR=root/CASSANDRA_OWNR=cassandra/' /etc/init.d/cassandra
        sudo sed -i 's/CASSANDRA_OWNR="root"/CASSANDRA_OWNR="cassandra"/' /etc/init.d/cassandra
    fi

    # 3. Ép lại quyền sở hữu thư mục
    chown -R cassandra:cassandra /etc/cassandra /var/lib/cassandra /var/log/cassandra 2>/dev/null || true
    
    log_ok "1.5 Hardened: Service will now run as 'cassandra' user."
}

verify_1_5() {
    audit_1_5
}
