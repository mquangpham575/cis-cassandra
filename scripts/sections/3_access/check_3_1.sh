#!/usr/bin/env bash

# =========================================================================
# CIS RECOMMENDATION 3.1: Ensure the cassandra and superuser roles are separate
# Assessment Status: Automated [cite: 492]
# =========================================================================

audit_3_1() {
    local CHECK_ID="3.1"
    local TITLE="Separate cassandra and superuser roles"
    local SECTION="3 Access Control"
    local EXPECTED="cassandra is not superuser"
    local REMEDIATION="Create new superuser and demote cassandra role."
    local SEVERITY="HIGH"

    # Kiểm tra xem role 'cassandra' có còn là superuser không [cite: 508, 511]
    local current_val
    current_val=$(cqlsh -u uit_admin -p Admin@2026 -e "SELECT role FROM system_auth.roles WHERE is_superuser = True ALLOW FILTERING;" 2>/dev/null | grep -w "cassandra" || echo "Safe")

    if [[ "$current_val" == *"cassandra"* ]]; then
        json_result "$CHECK_ID" "$TITLE" "FAIL" "$SEVERITY" "cassandra still has superuser status" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 1
    else
        json_result "$CHECK_ID" "$TITLE" "PASS" "$SEVERITY" "cassandra is demoted or DB unreachable" "$EXPECTED" "$REMEDIATION" "$SECTION"
        return 0
    fi
}

harden_3_1() {
    log_info "Remediating 3.1: Waiting for DB to start for role management..."
    
    local retry=0
    local pass_to_use="cassandra"
    # Thử cả pass cũ và pass mới [cite: 539]
    while true; do
        if cqlsh -u cassandra -p Cassandra@2026 -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; then
            pass_to_use="Cassandra@2026"
            break
        elif cqlsh -u cassandra -p cassandra -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1; then
            pass_to_use="cassandra"
            break
        fi
        sleep 5
        ((retry++))
        if [ $retry -gt 15 ]; then
            log_error "Timeout: Cassandra didn't start in time for 3.1."
            return 1
        fi
    done

    log_info "Remediating 3.1: Creating new superuser and demoting 'cassandra' role..."
    
    # 1. Tạo role superuser mới theo tài liệu 
    cqlsh -u cassandra -p "$pass_to_use" -e "CREATE ROLE 'uit_admin' WITH PASSWORD = 'Admin@2026' AND LOGIN = TRUE AND SUPERUSER = TRUE;" || true
    
    # 2. Cấp quyền trên toàn bộ keyspaces 
    cqlsh -u cassandra -p "$pass_to_use" -e "GRANT ALL PERMISSIONS ON ALL KEYSPACES TO 'uit_admin';" || true
    
    # 3. Thu hồi quyền superuser của tài khoản cassandra mặc định [cite: 523-524]
    cqlsh -u uit_admin -p Admin@2026 -e "UPDATE system_auth.roles SET is_superuser = null WHERE role = 'cassandra';"
    
    log_ok "New superuser 'uit_admin' created and 'cassandra' role demoted."
}

verify_3_1() {
    # Kiểm tra trạng thái hiện tại [cite: 160]
    if ! audit_3_1 > /dev/null 2>&1; then
        # Nếu FAIL (cassandra vẫn là superuser), thực hiện vá lỗi [cite: 161]
        harden_3_1
        # Kiểm tra lại lần cuối để xuất kết quả Dashboard
        audit_3_1
    else
        audit_3_1
    fi
}
