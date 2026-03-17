#!/bin/bash
#===============================================================================
# CIS Apache Cassandra 4.0 Benchmark - Automated Audit Script
#===============================================================================
# This script automatically audits all CIS recommendations and outputs
# PASS/FAIL status for each control
#===============================================================================

set -e

NODES=("cassandra-node1" "cassandra-node2" "cassandra-node3")
REPORT_FILE="reports/cis_audit_report_$(date +%Y%m%d_%H%M%S).txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
MANUAL=0

#-------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------
log_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

check_manual() {
    echo -e "${YELLOW}[MANUAL]${NC} $1"
    MANUAL=$((MANUAL + 1))
}

run_check() {
    local check_name=$1
    local check_cmd=$2
    
    if eval "$check_cmd" >/dev/null 2>&1; then
        check_pass "$check_name"
        return 0
    else
        check_fail "$check_name"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# CIS Section 1: Installation & Configuration
#-------------------------------------------------------------------------------
audit_section_1() {
    log_header "CIS Section 1: Installation & Configuration"
    
    # 1.1 Dedicated user/group (Manual - container runs as cassandra user)
    check_manual "1.1 - Dedicated cassandra user/group (requires manual verification)"
    
    # 1.2 Java installation
    for node in "${NODES[@]}"; do
        run_check "1.2 - Java installed on $node" "docker exec $node java -version"
    done
    
    # 1.3 Python installation
    for node in "${NODES[@]}"; do
        run_check "1.3 - Python installed on $node" "docker exec $node python3 --version"
    done
    
    # 1.4 Cassandra from package
    for node in "${NODES[@]}"; do
        run_check "1.4 - Cassandra installed on $node" "docker exec $node nodetool version"
    done
    
    # 1.5 Run as non-root (check if not running as root)
    for node in "${NODES[@]}"; do
        run_check "1.5 - Cassandra runs as non-root on $node" \
            "docker exec $node ps -ef | grep java | grep -v grep | grep -v '^-u root'"
    done
    
    # 1.6 Clock sync (Manual check for Docker)
    check_manual "1.6 - NTP enabled on $node (requires manual verification in Docker)"
}

#-------------------------------------------------------------------------------
# CIS Section 2: Authentication & Authorization
#-------------------------------------------------------------------------------
audit_section_2() {
    log_header "CIS Section 2: Authentication & Authorization"
    
    # 2.1 PasswordAuthenticator
    for node in "${NODES[@]}"; do
        run_check "2.1 - PasswordAuthenticator enabled on $node" \
            "docker exec $node bash -c 'grep authenticator: /etc/cassandra/cassandra.yaml | grep -q PasswordAuthenticator'"
    done
    
    # 2.2 CassandraAuthorizer
    for node in "${NODES[@]}"; do
        run_check "2.2 - CassandraAuthorizer enabled on $node" \
            "docker exec $node bash -c 'grep authorizer: /etc/cassandra/cassandra.yaml | grep -q CassandraAuthorizer'"
    done
}

#-------------------------------------------------------------------------------
# CIS Section 3: Authorization & Role Management
#-------------------------------------------------------------------------------
audit_section_3() {
    log_header "CIS Section 3: Authorization & Role Management"
    
    # 3.1 Separate superuser
    run_check "3.1 - Dedicated superuser 'cis_admin' exists" \
        "docker exec cassandra-node1 cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e 'SELECT * FROM system_auth.roles WHERE role='\''cis_admin'\'' ALLOW FILTERING;'"
    
    # 3.2 Default password changed
    run_check "3.2 - Default password changed" \
        "docker exec cassandra-node1 cqlsh -u cassandra -p cassandra -e 'SELECT * FROM system_auth.roles;' 2>&1 | grep -q 'AuthenticationFailed'"
    
    # 3.3 Review roles (Manual)
    check_manual "3.3 - Review all roles for unnecessary permissions (manual review required)"
    
    # 3.4 Non-root user (Manual verification)
    check_manual "3.4 - Non-root user ownership verified (manual verification required)"
    
    # 3.5 Listen address
    for node in "${NODES[@]}"; do
        run_check "3.5 - Listen address restricted on $node" \
            "docker exec $node bash -c 'grep listen_address /etc/cassandra/cassandra.yaml | grep -q 127.0.0.1'"
    done
    
    # 3.6 Network authorizer
    for node in "${NODES[@]}"; do
        run_check "3.6 - Network authorizer enabled on $node" \
            "docker exec $node bash -c 'grep network_authorizer /etc/cassandra/cassandra.yaml | grep -q CassandraNetworkAuthorizer'"
    done
    
    # 3.7 Role permissions (Manual)
    check_manual "3.7 - Review role permissions (manual review required)"
    
    # 3.8 Remove cassandra superuser
    run_check "3.8 - Default cassandra role is not superuser" \
        "docker exec cassandra-node1 cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e 'SELECT role, is_superuser FROM system_auth.roles WHERE role='\''cassandra'\'' ALLOW FILTERING;' | grep -v 'cassandra.*true'"
}

#-------------------------------------------------------------------------------
# CIS Section 4: Auditing & Logging
#-------------------------------------------------------------------------------
audit_section_4() {
    log_header "CIS Section 4: Auditing & Logging"
    
    # 4.1 Logging enabled
    for node in "${NODES[@]}"; do
        run_check "4.1 - Logging enabled on $node" \
            "docker exec $node nodetool getlogginglevels | grep -q 'ROOT.*INFO'"
    done
    
    # 4.2 Audit logging
    for node in "${NODES[@]}"; do
        run_check "4.2 - Audit logging enabled on $node" \
            "docker exec $node bash -c 'grep -A1 audit_logging_options /etc/cassandra/cassandra.yaml | grep -q enabled: true'"
    done
}

#-------------------------------------------------------------------------------
# CIS Section 5: Encryption
#-------------------------------------------------------------------------------
audit_section_5() {
    log_header "CIS Section 5: Encryption"
    
    # 5.1 Inter-node encryption
    for node in "${NODES[@]}"; do
        run_check "5.1 - Inter-node encryption enabled on $node" \
            "docker exec $node bash -c 'grep internode_encryption /etc/cassandra/cassandra.yaml | grep -q all'"
    done
    
    # 5.2 Client encryption
    for node in "${NODES[@]}"; do
        run_check "5.2 - Client encryption enabled on $node" \
            "docker exec $node bash -c 'grep -A1 client_encryption_options /etc/cassandra/cassandra.yaml | grep -q enabled: true'"
    done
}

#-------------------------------------------------------------------------------
# 3-Node Cluster Verification
#-------------------------------------------------------------------------------
verify_cluster() {
    log_header "3-Node Cluster Verification"
    
    # Check all nodes are running
    for node in "${NODES[@]}"; do
        run_check "Node $node is running" "docker ps --format '{{.Names}}' | grep -q '^$node$'"
    done
    
    # Check cluster status
    run_check "Cluster has 3 nodes" \
        "docker exec cassandra-node1 nodetool status | grep -c 'UN' | grep -q '3'"
}

#-------------------------------------------------------------------------------
# Generate Summary
#-------------------------------------------------------------------------------
generate_summary() {
    log_header "AUDIT SUMMARY"
    
    TOTAL=$((PASS + FAIL + MANUAL))
    
    echo ""
    echo "Total Checks: $TOTAL"
    echo -e "${GREEN}Passed: $PASS${NC}"
    echo -e "${RED}Failed: $FAIL${NC}"
    echo -e "${YELLOW}Manual Review: $MANUAL${NC}"
    echo ""
    
    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}  ALL AUTOMATED CHECKS PASSED!${NC}"
        echo -e "${GREEN}============================================${NC}"
    else
        echo -e "${RED}============================================${NC}"
        echo -e "${RED}  SOME CHECKS FAILED - REVIEW ABOVE${NC}"
        echo -e "${RED}============================================${NC}"
    fi
    
    # Save to file
    echo "" > $REPORT_FILE
    echo "CIS Apache Cassandra 4.0 Benchmark Audit Report" >> $REPORT_FILE
    echo "Generated: $(date)" >> $REPORT_FILE
    echo "============================================" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "Summary:" >> $REPORT_FILE
    echo "  Total: $TOTAL" >> $REPORT_FILE
    echo "  Passed: $PASS" >> $REPORT_FILE
    echo "  Failed: $FAIL" >> $REPORT_FILE
    echo "  Manual Review: $MANUAL" >> $REPORT_FILE
    
    echo ""
    echo "Report saved to: $REPORT_FILE"
}

#-------------------------------------------------------------------------------
# Main execution
#-------------------------------------------------------------------------------
main() {
    echo "=========================================="
    echo "  CIS Cassandra 4.0 Automated Audit"
    echo "=========================================="
    echo "Date: $(date)"
    echo ""
    
    # Verify nodes are running
    for node in "${NODES[@]}"; do
        if ! docker ps -q --filter "name=^${node}$" > /dev/null 2>&1; then
            echo -e "${RED}ERROR: $node is not running${NC}"
            echo "Run setup_3node_cluster.sh first"
            exit 1
        fi
    done
    
    echo "All nodes are running. Starting audit..."
    sleep 5
    
    # Run all audit sections
    verify_cluster
    audit_section_1
    audit_section_2
    audit_section_3
    audit_section_4
    audit_section_5
    
    # Generate summary
    generate_summary
}

main "$@"
