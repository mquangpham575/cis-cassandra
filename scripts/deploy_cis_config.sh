#!/bin/bash
#===============================================================================
# CIS Cassandra 4.0 - Configuration Deployment Script
#===============================================================================
# This script applies all CIS hardening configurations to all 3 nodes
# Run this AFTER setup_3node_cluster.sh
#===============================================================================

set -e

NODES=("cassandra-node1" "cassandra-node2" "cassandra-node3")
CASSANDRA_YAML="/etc/cassandra/cassandra.yaml"

# CIS Hardening Settings
NEW_CASSANDRA_PASSWORD='N3wStr0ng@Pass!'
CIS_ADMIN_PASSWORD='Adm1n@Secure99!'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#-------------------------------------------------------------------------------
# Wait for node to be ready
#-------------------------------------------------------------------------------
wait_for_node() {
    local node=$1
    log_info "Waiting for $node to be ready..."
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker exec $node nodetool describecluster >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    return 1
}

#-------------------------------------------------------------------------------
# Apply authentication settings via sed
#-------------------------------------------------------------------------------
apply_auth_settings() {
    log_info "Applying authentication settings..."
    
    for node in "${NODES[@]}"; do
        wait_for_node $node
        
        # Enable PasswordAuthenticator
        docker exec "$node" bash -c "sed -i 's/^authenticator: AllowAllAuthenticator/authenticator: PasswordAuthenticator/' $CASSANDRA_YAML"
        
        # Enable CassandraAuthorizer
        docker exec "$node" bash -c "sed -i 's/^authorizer: AllowAllAuthorizer/authorizer: CassandraAuthorizer/' $CASSANDRA_YAML"
        
        # Verify the change
        log_info "Verifying auth settings on $node..."
        docker exec "$node" bash -c "grep -E '^(authenticator|authorizer):' $CASSANDRA_YAML"
    done
    
    log_info "Auth settings applied"
}

#-------------------------------------------------------------------------------
# Apply network authorizer (CIS 3.6)
#-------------------------------------------------------------------------------
apply_network_settings() {
    log_info "Applying network settings..."
    
    for node in "${NODES[@]}"; do
        docker exec "$node" bash -c "echo '' >> $CASSANDRA_YAML && echo 'network_authorizer: CassandraNetworkAuthorizer' >> $CASSANDRA_YAML"
    done
    
    log_info "Network settings applied"
}

#-------------------------------------------------------------------------------
# Enable audit logging (CIS 4.2)
#-------------------------------------------------------------------------------
apply_audit_logging() {
    log_info "Applying audit logging settings..."
    
    for node in "${NODES[@]}"; do
        docker exec "$node" bash -c "echo '' >> $CASSANDRA_YAML && echo 'audit_logging_options:' >> $CASSANDRA_YAML && echo '    enabled: true' >> $CASSANDRA_YAML"
    done
    
    log_info "Audit logging enabled"
}

#-------------------------------------------------------------------------------
# Configure roles and passwords
#-------------------------------------------------------------------------------
configure_roles() {
    log_info "Configuring roles and passwords..."
    
    sleep 10
    
    docker exec cassandra-node1 cqlsh -u cassandra -p cassandra -e "
        ALTER ROLE 'cassandra' WITH PASSWORD = '$NEW_CASSANDRA_PASSWORD';
        CREATE ROLE IF NOT EXISTS 'cis_admin' WITH PASSWORD='$CIS_ADMIN_PASSWORD' AND LOGIN=TRUE AND SUPERUSER=TRUE;
        GRANT ALL PERMISSIONS ON ALL KEYSPACES TO cis_admin;
        ALTER ROLE cassandra WITH SUPERUSER = false;
    " 2>/dev/null || log_warn "Roles may already be configured"
    
    log_info "Roles configured"
}

#-------------------------------------------------------------------------------
# Restart cluster
#-------------------------------------------------------------------------------
restart_cluster() {
    log_info "Restarting cluster to apply changes..."
    
    for node in "${NODES[@]}"; do
        docker restart $node
    done
    
    log_info "Waiting for cluster to stabilize..."
    sleep 90
    
    for node in "${NODES[@]}"; do
        log_info "$node status:"
        docker exec $node nodetool status 2>/dev/null || true
    done
}

#-------------------------------------------------------------------------------
# Main execution
#-------------------------------------------------------------------------------
main() {
    echo "=========================================="
    echo "  CIS Hardening - Config Deployment"
    echo "=========================================="
    
    # Check if nodes are running
    for node in "${NODES[@]}"; do
        if ! docker ps -q --filter "name=^${node}$" > /dev/null 2>&1; then
            log_error "Node $node is not running. Run setup_3node_cluster.sh first."
            exit 1
        fi
    done
    
    # Apply configurations via sed on running containers
    apply_auth_settings
    apply_network_settings
    apply_audit_logging
    
    # Restart and configure
    restart_cluster
    configure_roles
    
    echo ""
    log_info "=========================================="
    log_info "  CIS Configuration Complete!"
    log_info "=========================================="
    echo ""
    echo "Verification commands:"
    echo "  docker exec cassandra-node1 nodetool status"
    echo "  docker exec cassandra-node1 cqlsh -u cis_admin -p '$CIS_ADMIN_PASSWORD'"
    echo ""
}

main "$@"
