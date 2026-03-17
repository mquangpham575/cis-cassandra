#!/bin/bash
#===============================================================================
# CIS Cassandra 4.0 - Manual Configuration Script
#===============================================================================
# This script handles manual CIS configurations that require special setup
# Run this AFTER setup_3node_cluster.sh
#
# Usage:
#   bash scripts/manual_config.sh ssl      - Setup SSL encryption
#   bash scripts/manual_config.sh roles    - Review roles & permissions
#   bash scripts/manual_config.sh verify    - Verify non-root user
#   bash scripts/manual_config.sh all       - Run all options
#===============================================================================

NODES=("cassandra-node1" "cassandra-node2" "cassandra-node3")
CIS_ADMIN_PASSWORD='Adm1n@Secure99!'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

#-------------------------------------------------------------------------------
# Setup SSL certificates and encryption (CIS 5.1, 5.2) using openssl
#-------------------------------------------------------------------------------
setup_ssl_encryption() {
    echo "=========================================="
    echo "  Setting up SSL Encryption (CIS 5.1, 5.2)"
    echo "=========================================="
    
    log_info "This requires OpenSSL on your host machine"
    log_info "Generating self-signed certificates..."
    
    # Generate private key and certificate using openssl on host
    openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
        -keyout config/ssl/server-key.pem \
        -out config/ssl/server-cert.pem \
        -subj "/CN=Cassandra/OU=DevSecOps/O=Study/L=City/ST=State/C=US" 2>/dev/null
    
    # Convert to PKCS12 format for Java keystore
    openssl pkcs12 -export \
        -in config/ssl/server-cert.pem \
        -inkey config/ssl/server-key.pem \
        -out config/ssl/keystore.p12 \
        -name cassandra \
        -password pass:cassandra123 2>/dev/null
    
    # Create truststore
    openssl pkcs12 -export \
        -in config/ssl/server-cert.pem \
        -out config/ssl/truststore.p12 \
        -name cassandra \
        -password pass:cassandra123 2>/dev/null
    
    log_info "Certificates generated"
    
    # Copy to all nodes
    for node in "${NODES[@]}"; do
        log_info "Configuring SSL on $node..."
        
        # Create SSL directory
        docker exec $node mkdir -p /etc/cassandra/ssl
        
        # Copy certificates
        docker cp config/ssl/server-key.pem $node:/etc/cassandra/ssl/server-key.pem
        docker cp config/ssl/server-cert.pem $node:/etc/cassandra/ssl/server-cert.pem
        docker cp config/ssl/keystore.p12 $node:/etc/cassandra/ssl/keystore.p12
        docker cp config/ssl/truststore.p12 $node:/etc/cassandra/ssl/truststore.p12
        
        # Set permissions
        docker exec $node chown -R cassandra:cassandra /etc/cassandra/ssl
        docker exec $node chmod 600 /etc/cassandra/ssl/server-key.pem
        docker exec $node chmod 644 /etc/cassandra/ssl/*.pem
        
        # Add encryption settings to yaml
        docker exec $node bash -c "echo '' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo 'server_encryption_options:' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    internode_encryption: all' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    certificate: /etc/cassandra/ssl/server-cert.pem' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    key: /etc/cassandra/ssl/server-key.pem' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    trust_certificate: /etc/cassandra/ssl/server-cert.pem' >> /etc/cassandra/cassandra.yaml"
        
        docker exec $node bash -c "echo '' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo 'client_encryption_options:' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    enabled: true' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    optional: false' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    certificate: /etc/cassandra/ssl/server-cert.pem' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    key: /etc/cassandra/ssl/server-key.pem' >> /etc/cassandra/cassandra.yaml"
        docker exec $node bash -c "echo '    trust_certificate: /etc/cassandra/ssl/server-cert.pem' >> /etc/cassandra/cassandra.yaml"
    done
    
    log_info "SSL certificates configured. Restarting cluster..."
    
    # Restart cluster
    for node in "${NODES[@]}"; do
        docker restart $node
    done
    
    sleep 60
    
    log_info "Encryption setup complete!"
}

#-------------------------------------------------------------------------------
# Review roles and permissions (CIS 3.3, 3.7)
#-------------------------------------------------------------------------------
review_roles() {
    echo "=========================================="
    echo "  Role & Permission Review (CIS 3.3, 3.7)"
    echo "=========================================="
    
    echo ""
    echo "Current roles in system_auth.roles:"
    docker exec cassandra-node1 cqlsh -u cis_admin -p "$CIS_ADMIN_PASSWORD" -e "SELECT * FROM system_auth.roles;"
    
    echo ""
    echo "Current permissions:"
    docker exec cassandra-node1 cqlsh -u cis_admin -p "$CIS_ADMIN_PASSWORD" -e "LIST ALL PERMISSIONS;"
    
    echo ""
    echo "To modify permissions, use:"
    echo "  GRANT <permission> ON <resource> TO <role>;"
    echo "  REVOKE <permission> ON <resource> FROM <role>;"
}

#-------------------------------------------------------------------------------
# Verify non-root user (CIS 1.1, 3.4)
#-------------------------------------------------------------------------------
verify_non_root() {
    echo "=========================================="
    echo "  Verify Non-Root User (CIS 1.1, 3.4)"
    echo "=========================================="
    
    for node in "${NODES[@]}"; do
        echo ""
        echo "=== $node ==="
        docker exec $node bash -c "id"
        docker exec $node bash -c "ps -ef | grep java"
    done
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
case "$1" in
    ssl)
        setup_ssl_encryption
        ;;
    roles)
        review_roles
        ;;
    verify)
        verify_non_root
        ;;
    all)
        setup_ssl_encryption
        review_roles
        verify_non_root
        ;;
    *)
        echo "Usage: $0 {ssl|roles|verify|all}"
        echo ""
        echo "Options:"
        echo "  ssl     - Setup SSL encryption (CIS 5.1, 5.2)"
        echo "  roles   - Review roles & permissions (CIS 3.3, 3.7)"
        echo "  verify  - Verify non-root user (CIS 1.1, 3.4)"
        echo "  all     - Run all options"
        ;;
esac
