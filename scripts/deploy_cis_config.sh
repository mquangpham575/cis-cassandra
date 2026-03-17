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
LOGBACK_XML="/etc/cassandra/logback.xml"

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
# Apply configuration to a single node
#-------------------------------------------------------------------------------
apply_to_node() {
    local node=$1
    log_info "Applying CIS configs to $node..."
    
    # Wait for node to be ready
    log_info "Waiting for $node to be ready..."
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker exec $node nodetool describecluster >/dev/null 2>&1; then
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    # Copy config files to node
    log_info "Copying cassandra.yaml to $node..."
    docker cp config/cassandra.yaml $node:$CASSANDRA_YAML
    
    # Set permissions
    docker exec bash -c "chown cassandra:cassandra $CASSANDRA_YAML && chmod 644 $CASSANDRA_YAML"
    
    log_info "CIS configs applied to $node"
}

#-------------------------------------------------------------------------------
# Apply authentication settings via CQL
#-------------------------------------------------------------------------------
apply_auth_settings() {
    log_info "Applying authentication settings..."
    
    # Enable PasswordAuthenticator and CassandraAuthorizer
    for node in "${NODES[@]}"; do
        docker exec $node sed -i 's/authenticator: AllowAllAuthenticator/authenticator: PasswordAuthenticator/' $CASSANDRA_YAML
        docker exec $node sed -i 's/authorizer: AllowAllAuthorizer/authorizer: CassandraAuthorizer/' $CASSANDRA_YAML
    done
    
    log_info "Auth settings applied to YAML"
}

#-------------------------------------------------------------------------------
# Create dedicated cassandra user/group (CIS 1.1, 1.5, 3.4)
#-------------------------------------------------------------------------------
create_cassandra_user() {
    log_info "Creating dedicated cassandra user and group..."
    
    for node in "${NODES[@]}"; do
        docker exec $node groupadd -g 2000 cassandra 2>/dev/null || log_warn "Group may exist"
        docker exec $node useradd -m -d /home/cassandra -s /bin/bash -g cassandra -u 2000 cassandra 2>/dev/null || log_warn "User may exist"
    done
    
    log_info "User/group created"
}

#-------------------------------------------------------------------------------
# Create SSL certificates (CIS 5.1, 5.2)
#-------------------------------------------------------------------------------
create_ssl_certs() {
    log_info "Creating SSL certificates..."
    
    for node in "${NODES[@]}"; do
        docker exec $node mkdir -p /etc/cassandra/ssl
        docker exec $node keytool -genkey \
            -alias cassandra \
            -keyalg RSA \
            -keysize 2048 \
            -keystore /etc/cassandra/ssl/keystore.jks \
            -storepass cassandra123 \
            -keypass cassandra123 \
            -dname "CN=cassandra, OU=lab, O=lab, L=lab, S=lab, C=US" \
            -validity 365 2>/dev/null || log_warn "Keystore may exist"
        
        docker exec $node keytool -export \
            -alias cassandra \
            -file /etc/cassandra/ssl/cassandra.crt \
            -keystore /etc/cassandra/ssl/keystore.jks \
            -storepass cassandra123 2>/dev/null || true
        
        docker exec $node keytool -import \
            -alias cassandra \
            -file /etc/cassandra/ssl/cassandra.crt \
            -keystore /etc/cassandra/ssl/truststore.jks \
            -storepass cassandra123 \
            -noprompt 2>/dev/null || log_warn "Truststore may exist"
        
        docker exec $node chown -R cassandra:cassandra /etc/cassandra/ssl
    done
    
    log_info "SSL certificates created"
}

#-------------------------------------------------------------------------------
# Apply encryption settings (CIS 5.1, 5.2)
#-------------------------------------------------------------------------------
apply_encryption() {
    log_info "Applying encryption settings..."
    
    for node in "${NODES[@]}"; do
        # Enable inter-node encryption (CIS 5.1)
        docker exec $node sed -i 's/internode_encryption: none/internode_encryption: all/' $CASSANDRA_YAML
        
        # Enable client encryption (CIS 5.2)
        docker exec $node sed -i 's/^  # enabled: true/  enabled: true/' $CASSANDRA_YAML
        docker exec $node sed -i 's/^  # optional: true/  optional: false/' $CASSANDRA_YAML
        
        # Set keystore paths
        docker exec $node sed -i 's|# keystore: /etc/cassandra/conf/keystore.jks|keystore: /etc/cassandra/ssl/keystore.jks|' $CASSANDRA_YAML
        docker exec $node sed -i 's|# keystore_password: keystore_password|keystore_password: cassandra123|' $CASSANDRA_YAML
        docker exec $node sed -i 's|# truststore: /etc/cassandra/conf/truststore.jks|truststore: /etc/cassandra/ssl/truststore.jks|' $CASSANDRA_YAML
        docker exec $node sed -i 's|# truststore_password: truststore_password|truststore_password: cassandra123|' $CASSANDRA_YAML
    done
    
    log_info "Encryption settings applied"
}

#-------------------------------------------------------------------------------
# Apply network settings (CIS 3.5, 3.6)
#-------------------------------------------------------------------------------
apply_network_settings() {
    log_info "Applying network settings..."
    
    for node in "${NODES[@]}"; do
        # Set listen address to localhost (CIS 3.5)
        docker exec $node sed -i 's/listen_address: localhost/listen_address: 127.0.0.1/' $CASSANDRA_YAML
        
        # Enable network authorizer (CIS 3.6)
        docker exec $node sed -i 's/network_authorizer: AllowAllNetworkAuthorizer/network_authorizer: CassandraNetworkAuthorizer/' $CASSANDRA_YAML
    done
    
    log_info "Network settings applied"
}

#-------------------------------------------------------------------------------
# Enable audit logging (CIS 4.2)
#-------------------------------------------------------------------------------
apply_audit_logging() {
    log_info "Applying audit logging settings..."
    
    for node in "${NODES[@]}"; do
        docker exec $node sed -i 's/audit_logging_options:/audit_logging_options:\n  enabled: true/' $CASSANDRA_YAML
    done
    
    log_info "Audit logging enabled"
}

#-------------------------------------------------------------------------------
# Create CIS admin role and configure passwords
#-------------------------------------------------------------------------------
configure_roles() {
    log_info "Configuring roles and passwords..."
    
    # Wait for auth to be enabled
    sleep 10
    
    # Change default password and create admin
    docker exec cassandra-node1 cqlsh -u cassandra -p cassandra -e "
        ALTER ROLE 'cassandra' WITH PASSWORD = '$NEW_CASSANDRA_PASSWORD';
        CREATE ROLE IF NOT EXISTS 'cis_admin' WITH PASSWORD='$CIS_ADMIN_PASSWORD' AND LOGIN=TRUE AND SUPERUSER=TRUE;
        GRANT ALL PERMISSIONS ON ALL KEYSPACES TO cis_admin;
        ALTER ROLE cassandra WITH SUPERUSER = false;
    " 2>/dev/null || log_warn "Roles may already be configured"
    
    log_info "Roles configured"
}

#-------------------------------------------------------------------------------
# Restart all nodes to apply changes
#-------------------------------------------------------------------------------
restart_cluster() {
    log_info "Restarting cluster to apply changes..."
    
    for node in "${NODES[@]}"; do
        docker restart $node
    done
    
    log_info "Waiting for cluster to stabilize..."
    sleep 45
    
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
        if ! docker ps | grep -q $node; then
            log_error "Node $node is not running. Run setup_3node_cluster.sh first."
            exit 1
        fi
    done
    
    # Create cassandra user first (needed for chown)
    create_cassandra_user
    
    # Create SSL certificates
    create_ssl_certs
    
    # Apply config to each node
    for node in "${NODES[@]}"; do
        apply_to_node $node
    done
    
    # Apply all remaining configurations
    apply_auth_settings
    apply_network_settings
    apply_audit_logging
    apply_encryption
    
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
