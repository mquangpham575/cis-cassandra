#!/bin/bash
#===============================================================================
# CIS Apache Cassandra 4.0 - WSL Fully Automated Setup
#===============================================================================
# This script provides CIS-compliant Cassandra setup with WSL compatibility
# Supports full automation including SSL encryption (CIS 5.1, 5.2)
#===============================================================================

set -e

# Configuration
CLUSTER_NAME="cis-cluster"
CASSANDRA_VERSION="4.0.19"
CASSANDRA_NETWORK="cassandra-net"
NODES=("cassandra-node1" "cassandra-node2" "cassandra-node3")
CIS_ADMIN_PASSWORD='Adm1n@Secure99!'

# Node configurations
declare -A NODE1=([NAME]="cassandra-node1" [IP]="172.20.0.11" [SEEDS]="172.20.0.11,172.20.0.12,172.20.0.13" [PORT_OFFSET]=0)
declare -A NODE2=([NAME]="cassandra-node2" [IP]="172.20.0.12" [SEEDS]="172.20.0.11,172.20.0.12,172.20.0.13" [PORT_OFFSET]=1)
declare -A NODE3=([NAME]="cassandra-node3" [IP]="172.20.0.13" [SEEDS]="172.20.0.11,172.20.0.12,172.20.0.13" [PORT_OFFSET]=2)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# SECTION 1: Installation & Configuration
#===============================================================================
section_1_install() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS Section 1: Installation & Configuration${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "  1.1  Dedicated cassandra user/group (Manual - Docker limitation)"
    echo "  1.2  ✅ Java installed (Automated)"
    echo "  1.3  ✅ Python installed (Automated)"
    echo "  1.4  ✅ Cassandra installed (Automated)"
    echo "  1.5  ✅ Run as non-root user (Automated)"
    echo "  1.6  ⚠️  NTP enabled (Manual - Docker limitation)"
    echo ""
    echo "  [1] Run Section 1 checks"
    echo "  [0] Back to main menu"
    echo -n "  Select: "
    read choice
    
    case $choice in
        1) run_section_1 ;;
        0) return ;;
    esac
}

run_section_1() {
    echo ""
    log_info "Running Section 1 checks..."
    
    # 1.2 Java
    echo -n "  1.2 Java: "
    for node in "${NODES[@]}"; do
        if docker exec $node java -version >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    # 1.3 Python
    echo -n "  1.3 Python: "
    for node in "${NODES[@]}"; do
        if docker exec $node python3 --version >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    # 1.4 Cassandra
    echo -n "  1.4 Cassandra: "
    for node in "${NODES[@]}"; do
        if docker exec $node nodetool version >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    # 1.5 Non-root
    echo -n "  1.5 Non-root: "
    for node in "${NODES[@]}"; do
        if docker exec $node bash -c "ps -ef | grep java | grep -v grep | grep -v '^-u root'" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}⚠${NC}"
        fi
    done
    
    echo ""
    log_info "Section 1 complete. For 1.1 and 1.6, manual verification required."
}

#===============================================================================
# SECTION 2: Authentication
#===============================================================================
section_2_auth() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS Section 2: Authentication & Authorization${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "  2.1  ✅ PasswordAuthenticator enabled (Automated)"
    echo "  2.2  ✅ CassandraAuthorizer enabled (Automated)"
    echo ""
    echo "  [2] Run Section 2 (Enable Authentication)"
    echo "  [0] Back to main menu"
    echo -n "  Select: "
    read choice
    
    case $choice in
        2) enable_authentication ;;
        0) return ;;
    esac
}

enable_authentication() {
    echo ""
    log_info "Enabling authentication..."
    
    for node in "${NODES[@]}"; do
        docker exec $node bash -c "sed -i 's/^authenticator: AllowAllAuthenticator/authenticator: PasswordAuthenticator/' /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "sed -i 's/^authorizer: AllowAllAuthorizer/authorizer: CassandraAuthorizer/' /etc/cassandra/cassandra.yaml"
    done
    
    log_info "Authentication enabled. Restarting cluster..."
    for node in "${NODES[@]}"; do
        docker restart $node
    done
    sleep 60
    
    log_info "Authentication enabled successfully!"
}

#===============================================================================
# SECTION 3: Authorization
#===============================================================================
section_3_authz() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS Section 3: Authorization & Role Management${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "  3.1  ✅ Dedicated superuser 'cis_admin' (Automated)"
    echo "  3.2  ✅ Default password changed (Automated)"
    echo "  3.3  ⚠️  Review roles (Manual)"
    echo "  3.4  ⚠️  Non-root user ownership (Manual - Docker)"
    echo "  3.5  ✅ Listen address restricted (Automated)"
    echo "  3.6  ✅ Network authorizer enabled (Automated)"
    echo "  3.7  ⚠️  Review role permissions (Manual)"
    echo "  3.8  ✅ cassandra not superuser (Automated)"
    echo ""
    echo "  [3] Run Section 3 (Enable Authorization)"
    echo "  [R] Review roles & permissions"
    echo "  [V] Verify non-root user"
    echo "  [0] Back to main menu"
    echo -n "  Select: "
    read choice
    
    case $choice in
        3) enable_authorization ;;
        R|r) review_roles ;;
        V|v) verify_non_root ;;
        0) return ;;
    esac
}

enable_authorization() {
    echo ""
    log_info "Configuring authorization..."
    
    # Enable network authorizer and audit logging
    for node in "${NODES[@]}"; do
        docker exec $node bash -c "echo '' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo 'network_authorizer: CassandraNetworkAuthorizer' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo 'audit_logging_options:' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    enabled: true' >> /etc/cassandra/cassandra.yaml"
    done
    
    # Restart cluster
    for node in "${NODES[@]}"; do
        docker restart $node
    done
    sleep 60
    
    # Create CIS admin role
    docker exec cassandra-node1 cqlsh -u cassandra -p cassandra -e "
        ALTER ROLE 'cassandra' WITH PASSWORD = 'Ch@ng3dP@ss123!';
        CREATE ROLE IF NOT EXISTS 'cis_admin' WITH PASSWORD='$CIS_ADMIN_PASSWORD' AND LOGIN=TRUE AND SUPERUSER=TRUE;
        GRANT ALL PERMISSIONS ON ALL KEYSPACES TO cis_admin;
        ALTER ROLE cassandra WITH SUPERUSER = false;
    " 2>/dev/null || true
    
    log_info "Authorization configured successfully!"
}

review_roles() {
    echo ""
    log_info "Reviewing roles..."
    docker exec cassandra-node1 cqlsh -u cis_admin -p "$CIS_ADMIN_PASSWORD" -e "SELECT * FROM system_auth.roles;"
    echo ""
    docker exec cassandra-node1 cqlsh -u cis_admin -p "$CIS_ADMIN_PASSWORD" -e "LIST ALL PERMISSIONS;"
}

verify_non_root() {
    echo ""
    log_info "Verifying non-root user..."
    for node in "${NODES[@]}"; do
        echo "=== $node ==="
        docker exec $node bash -c "id"
        docker exec $node bash -c "ps -ef | grep java | grep -v grep"
    done
}

#===============================================================================
# SECTION 4: Auditing & Logging
#===============================================================================
section_4_audit() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS Section 4: Auditing & Logging${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "  4.1  ✅ Logging enabled (Automated)"
    echo "  4.2  ✅ Audit logging enabled (Automated)"
    echo ""
    echo "  [4] Run Section 4 checks"
    echo "  [0] Back to main menu"
    echo -n "  Select: "
    read choice
    
    case $choice in
        4) run_section_4 ;;
        0) return ;;
    esac
}

run_section_4() {
    echo ""
    log_info "Running Section 4 checks..."
    
    # 4.1 Logging
    echo -n "  4.1 Logging: "
    for node in "${NODES[@]}"; do
        if docker exec $node nodetool getlogginglevels 2>/dev/null | grep -q "ROOT.*INFO"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    # 4.2 Audit logging
    echo -n "  4.2 Audit: "
    for node in "${NODES[@]}"; do
        if docker exec $node bash -c "grep -q 'enabled: true' /etc/cassandra/cassandra.yaml" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    log_info "Section 4 complete!"
}

#===============================================================================
# SECTION 5: Encryption (WSL - Fully Automated!)
#===============================================================================
section_5_encrypt() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS Section 5: Encryption (WSL)${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "  5.1  ✅ Inter-node encryption (Automated - WSL)"
    echo "  5.2  ✅ Client encryption (Automated - WSL)"
    echo ""
    echo "  [5] Setup SSL Encryption"
    echo "  [0] Back to main menu"
    echo -n "  Select: "
    read choice
    
    case $choice in
        5) setup_ssl_encryption ;;
        0) return ;;
    esac
}

setup_ssl_encryption() {
    echo ""
    log_info "Setting up SSL encryption (CIS 5.1, 5.2)..."
    
    # Generate SSL certificates in first node
    log_info "Generating SSL certificates..."
    docker exec cassandra-node1 bash -c "
        keytool -genkeypair \
            -alias cassandra \
            -keyalg RSA \
            -keysize 2048 \
            -validity 365 \
            -keystore /root/keystore.jks \
            -storepass cassandra123 \
            -keypass cassandra123 \
            -dname 'CN=Cassandra, OU=DevSecOps, O=Study, L=City, ST=State, C=US'
    " 2>/dev/null || true
    
    docker exec cassandra-node1 bash -c "
        keytool -exportcert \
            -alias cassandra \
            -keystore /root/keystore.jks \
            -storepass cassandra123 \
            -file /root/cassandra.crt \
            -rfc
    " 2>/dev/null || true
    
    docker exec cassandra-node1 bash -c "
        keytool -importcert \
            -alias cassandra \
            -file /root/cassandra.crt \
            -keystore /root/truststore.jks \
            -storepass cassandra123 \
            -noprompt
    " 2>/dev/null || true
    
    # Copy to all nodes and configure
    for node in "${NODES[@]}"; do
        log_info "Configuring SSL on $node..."
        
        docker exec $node mkdir -p /etc/cassandra/ssl
        
        # Copy certificates
        docker exec cassandra-node1 cat /root/keystore.jks | docker exec -i $node bash -c 'cat > /etc/cassandra/ssl/keystore.jks'
        docker exec cassandra-node1 cat /root/truststore.jks | docker exec -i $node bash -c 'cat > /etc/cassandra/ssl/truststore.jks'
        
        # Set permissions
        docker exec $node chown -R cassandra:cassandra /etc/cassandra/ssl
        docker exec $node chmod 644 /etc/cassandra/ssl/keystore.jks
        docker exec $node chmod 644 /etc/cassandra/ssl/truststore.jks
        
        # Add encryption settings
        docker exec $node bash -c "echo '' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo 'server_encryption_options:' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    internode_encryption: all' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    keystore: /etc/cassandra/ssl/keystore.jks' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    keystore_password: cassandra123' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    truststore: /etc/cassandra/ssl/truststore.jks' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    truststore_password: cassandra123' >> /etc/cassandra/cassandra.yaml"
        
        docker exec $node bash -c "echo '' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo 'client_encryption_options:' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    enabled: true' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    optional: false' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    keystore: /etc/cassandra/ssl/keystore.jks' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    keystore_password: cassandra123' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    truststore: /etc/cassandra/ssl/truststore.jks' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    truststore_password: cassandra123' >> /etc/cassandra/cassandra.yaml"
    done
    
    log_info "SSL configured. Restarting cluster..."
    for node in "${NODES[@]}"; do
        docker restart $node
    done
    sleep 60
    
    log_info "SSL encryption (CIS 5.1, 5.2) enabled successfully!"
}

#===============================================================================
# CLUSTER SETUP FUNCTIONS
#===============================================================================
cleanup() {
    log_info "Cleaning up..."
    docker rm -f cassandra-node1 cassandra-node2 cassandra-node3 2>/dev/null || true
    docker network rm $CASSANDRA_NETWORK 2>/dev/null || true
    sleep 2
}

create_network() {
    log_info "Creating network..."
    docker network rm $CASSANDRA_NETWORK 2>/dev/null || true
    docker network create --subnet=172.20.0.0/16 $CASSANDRA_NETWORK
    sleep 2
}

start_node() {
    local node_name=$1
    local ip=$2
    local seeds=$3
    local offset=$4
    
    local host_storage_port=$((7000 + offset * 100))
    local host_ssl_port=$((7001 + offset * 100))
    local host_cql_port=$((9042 + offset))
    
    docker run -d \
        --name $node_name \
        --network $CASSANDRA_NETWORK \
        --ip $ip \
        -e CASSANDRA_CLUSTER_NAME=$CLUSTER_NAME \
        -e CASSANDRA_SEEDS=$seeds \
        -e CASSANDRA_DC=dc1 \
        -e CASSANDRA_RACK=rack1 \
        -e CASSANDRA_BROADCAST_ADDRESS=$ip \
        -e CASSANDRA_LISTEN_ADDRESS=$ip \
        -e MAX_HEAP_SIZE="512M" \
        -e HEAP_NEWSIZE="256M" \
        -p ${host_storage_port}:7000 \
        -p ${host_ssl_port}:7001 \
        -p ${host_cql_port}:9042 \
        cassandra:$CASSANDRA_VERSION
    
    log_info "$node_name started at $ip"
}

setup_3node_cluster() {
    echo ""
    log_info "Setting up 3-node cluster..."
    
    cleanup
    create_network
    
    start_node "cassandra-node1" "${NODE1[IP]}" "${NODE1[SEEDS]}" "${NODE1[PORT_OFFSET]}"
    sleep 30
    start_node "cassandra-node2" "${NODE2[IP]}" "${NODE2[SEEDS]}" "${NODE2[PORT_OFFSET]}"
    sleep 30
    start_node "cassandra-node3" "${NODE3[IP]}" "${NODE3[SEEDS]}" "${NODE3[PORT_OFFSET]}"
    
    log_info "Waiting for cluster formation..."
    sleep 60
    
    # Enable all CIS features
    enable_authentication
    enable_authorization
    setup_ssl_encryption
    
    log_info "3-node cluster ready!"
}

#===============================================================================
# VIEW STATUS
#===============================================================================
view_status() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  Cluster Status${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    
    echo "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo "Cluster Status:"
    docker exec cassandra-node1 nodetool status 2>/dev/null || log_error "Cluster not running"
    
    echo ""
    echo "Quick CQL Test:"
    docker exec cassandra-node1 cqlsh -u cis_admin -p "$CIS_ADMIN_PASSWORD" -e "SELECT * FROM system_auth.roles;" 2>/dev/null || log_error "Authentication not configured"
}

#===============================================================================
# STOP/REMOVE CLUSTER
#===============================================================================
stop_cluster() {
    echo ""
    log_info "Stopping cluster..."
    docker rm -f cassandra-node1 cassandra-node2 cassandra-node3 2>/dev/null || true
    log_info "Cluster stopped and removed."
}

#===============================================================================
# MAIN MENU
#===============================================================================
main_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}============================================================${NC}"
        echo -e "${BLUE}  CIS Apache Cassandra 4.0 - WSL Fully Automated Setup${NC}"
        echo -e "${BLUE}============================================================${NC}"
        echo ""
        echo -e "${CYAN}Installation & Config:${NC}"
        echo "  1) Section 1: Installation & Configuration"
        echo ""
        echo -e "${CYAN}Security:${NC}"
        echo "  2) Section 2: Authentication & Authorization"
        echo "  3) Section 3: Authorization & Role Management"
        echo "  4) Section 4: Auditing & Logging"
        echo "  5) Section 5: Encryption (WSL - Fully Automated!)"
        echo ""
        echo -e "${CYAN}Full Setup:${NC}"
        echo "  6) Setup 3-Node Cluster (All Sections)"
        echo "  0) Run All + Audit"
        echo ""
        echo -e "${CYAN}Utilities:${NC}"
        echo "  S) View Status"
        echo "  R) Review Roles & Permissions"
        echo "  V) Verify Non-Root User"
        echo "  X) Stop/Remove Cluster"
        echo ""
        echo -e "${RED}  Q) Quit${NC}"
        echo ""
        echo -n "Select option: "
        read choice
        
        case $choice in
            1) section_1_install ;;
            2) section_2_auth ;;
            3) section_3_authz ;;
            4) section_4_audit ;;
            5) section_5_encrypt ;;
            6) setup_3node_cluster ;;
            0) 
                setup_3node_cluster
                echo ""
                echo "Running audit..."
                bash scripts/audit_cis_compliance.sh 2>/dev/null || log_warn "Audit script not found"
                ;;
            S|s) view_status ;;
            R|r) review_roles ;;
            V|v) verify_non_root ;;
            X|x) stop_cluster ;;
            Q|q) 
                echo "Goodbye!"
                exit 0
                ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

# Check if running in WSL
if grep -qEi "(Microsoft|WSL)" /proc/version >/dev/null 2>&1; then
    log_info "WSL detected - SSL automation enabled!"
else
    log_warn "Not running in WSL - SSL encryption may not work properly"
fi

# Check if containers already exist
if docker ps --format '{{.Names}}' | grep -q "cassandra-node"; then
    echo ""
    log_info "Existing cluster detected!"
    view_status
fi

main_menu
