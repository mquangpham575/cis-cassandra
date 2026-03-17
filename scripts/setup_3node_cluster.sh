#!/bin/bash
#===============================================================================
# CIS Cassandra 4.0 - 3-Node Cluster Setup Script (Docker)
#===============================================================================
# This script creates a 3-node Cassandra cluster using Docker
# for CIS Benchmark hardening demonstration
#===============================================================================

set -e

CLUSTER_NAME="cis-cluster"
CASSANDRA_VERSION="4.0.19"
CASSANDRA_NETWORK="cassandra-net"

# Node configurations with ports
declare -A NODE1=([NAME]="cassandra-node1" [IP]="172.20.0.11" [SEEDS]="172.20.0.11,172.20.0.12,172.20.0.13" [PORT_OFFSET]=0)
declare -A NODE2=([NAME]="cassandra-node2" [IP]="172.20.0.12" [SEEDS]="172.20.0.11,172.20.0.12,172.20.0.13" [PORT_OFFSET]=1)
declare -A NODE3=([NAME]="cassandra-node3" [IP]="172.20.0.13" [SEEDS]="172.20.0.11,172.20.0.12,172.20.0.13" [PORT_OFFSET]=2)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#-------------------------------------------------------------------------------
# Cleanup existing containers and network
#-------------------------------------------------------------------------------
cleanup() {
    log_info "Cleaning up existing containers..."
    docker rm -f cassandra-node1 cassandra-node2 cassandra-node3 2>/dev/null || true
    docker network rm $CASSANDRA_NETWORK 2>/dev/null || true
    sleep 2
    log_info "Cleanup complete"
}

#-------------------------------------------------------------------------------
# Create Docker network
#-------------------------------------------------------------------------------
create_network() {
    log_info "Creating Docker network..."
    docker network rm $CASSANDRA_NETWORK 2>/dev/null || true
    docker network create --subnet=172.20.0.0/16 $CASSANDRA_NETWORK
    sleep 2
    log_info "Network created"
}

#-------------------------------------------------------------------------------
# Start Cassandra node
#-------------------------------------------------------------------------------
start_node() {
    local node_name=$1
    local ip=$2
    local seeds=$3
    local offset=$4
    
    local host_storage_port=$((7000 + offset))
    local host_ssl_port=$((7001 + offset))
    local host_cql_port=$((9042 + offset))
    
    log_info "Starting $node_name..."
    
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
        -p ${host_storage_port}:7000 \
        -p ${host_ssl_port}:7001 \
        -p ${host_cql_port}:9042 \
        cassandra:$CASSANDRA_VERSION
    
    log_info "$node_name started at $ip (ports: storage=$host_storage_port, ssl=$host_ssl_port, cql=$host_cql_port)"
}

#-------------------------------------------------------------------------------
# Wait for cluster to be ready
#-------------------------------------------------------------------------------
wait_for_cluster() {
    log_info "Waiting for cluster to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local status=$(docker exec cassandra-node1 nodetool status 2>/dev/null | grep -c "UN" || echo "0")
        if [ "$status" -ge "3" ]; then
            log_info "Cluster is ready with $status nodes"
            return 0
        fi
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    log_error "Cluster failed to start within expected time"
    return 1
}

#-------------------------------------------------------------------------------
# Main execution
#-------------------------------------------------------------------------------
main() {
    echo "=========================================="
    echo "  CIS Cassandra 3-Node Cluster Setup"
    echo "=========================================="
    
    cleanup
    create_network
    
    # Start nodes
    start_node "cassandra-node1" "${NODE1[IP]}" "${NODE1[SEEDS]}" "${NODE1[PORT_OFFSET]}"
    sleep 10
    start_node "cassandra-node2" "${NODE2[IP]}" "${NODE2[SEEDS]}" "${NODE2[PORT_OFFSET]}"
    sleep 10
    start_node "cassandra-node3" "${NODE3[IP]}" "${NODE3[SEEDS]}" "${NODE3[PORT_OFFSET]}"
    
    log_info "All nodes started. Waiting for cluster formation..."
    sleep 30
    
    # Show cluster status
    echo ""
    log_info "Cluster Status:"
    docker exec cassandra-node1 nodetool status
    
    echo ""
    log_info "=========================================="
    log_info "  3-Node Cluster Setup Complete!"
    log_info "=========================================="
    echo ""
    echo "Connection strings:"
    echo "  Node 1: cqlsh -h localhost -p 9042"
    echo "  Node 2: cqlsh -h localhost -p 9043"  
    echo "  Node 3: cqlsh -h localhost -p 9044"
    echo ""
    echo "To check status: docker exec cassandra-node1 nodetool status"
}

main "$@"
