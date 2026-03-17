#!/bin/bash
#===============================================================================
# CIS Apache Cassandra 4.0 - WSL Native Installation Script
#===============================================================================

set -e

# Configuration
CASSANDRA_VERSION="4.0.19"
CIS_ADMIN_PASSWORD='Adm1n@Secure99!'
NEW_CASSANDRA_PASSWORD='N3wStr0ng@Pass!'

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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

#===============================================================================
# CIS 1.0: Prerequisites
#===============================================================================
cis_1_0() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 1.0: Prerequisites${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Updating system..."
    apt-get update && apt-get upgrade -y
    
    log_info "Installing Java (CIS 1.2)..."
    apt-get install openjdk-8-jdk -y
    
    log_info "Installing Python 3.10 (CIS 1.3)..."
    sudo apt install python3.10
    python3.10 --version
    
    log_info "Prerequisites complete!"
}

#===============================================================================
# CIS 1.1: User/Group
#===============================================================================
cis_1_1() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 1.1: User/Group${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Creating cassandra group..."
    groupadd -f cassandra
    
    log_info "Creating cassandra user..."
    useradd -m -d /home/cassandra -s /bin/bash -g cassandra -u 2000 cassandra 2>/dev/null || true
    
    log_info "Verifying user/group..."
    getent group cassandra
    getent passwd cassandra
    
    log_info "User/Group complete!"
}

#===============================================================================
# CIS 1.4: Install Cassandra
#===============================================================================
cis_1_4() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 1.4: Install Cassandra${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Installing prerequisites..."
    sudo apt-get install curl gnupg -y
    
    log_info "Adding Cassandra repository..."
    sudo apt-get install -y gnupg2 curl
    curl -fsSL https://downloads.apache.org/cassandra/KEYS | sudo gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://debian.cassandra.apache.org 40x main" | sudo tee /etc/apt/sources.list.d/cassandra.sources.list
    
    log_info "Installing Cassandra..."
    sudo apt-get update
    sudo apt-get install cassandra -y
    
    log_info "Verifying Cassandra version..."
    cassandra -v
    
    log_info "Cassandra installation complete!"
}

#===============================================================================
# CIS 1.6: Clock Sync
#===============================================================================
cis_1_6() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 1.6: Clock Sync${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    sudo apt install systemd-timesyncd
    sudo timedatectl set-ntp true
    timedatectl status
    
    log_info "Clock sync complete!"
}

#===============================================================================
# CIS 1.5: Ownership & Start
#===============================================================================
cis_1_5() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 1.5: Ownership & Start${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Fixing ownership..."
    chown -R cassandra:cassandra /var/lib/cassandra
    chown -R cassandra:cassandra /var/log/cassandra
    chown -R cassandra:cassandra /etc/cassandra
    
    log_info "Starting Cassandra..."
    sudo -u cassandra cassandra -f &
    
    log_info "Waiting for Cassandra to start..."
    sleep 10
    
    log_info "Verifying process owner..."
    ps -aef | grep cassandra | grep java | cut -d' ' -f1
    
    log_info "Ownership complete!"
}

#===============================================================================
# CIS 2.1, 2.2: Authentication
#===============================================================================
cis_2_1() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 2.1, 2.2: Authentication${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Enabling PasswordAuthenticator..."
    sed -i 's/authenticator: AllowAllAuthenticator/authenticator: PasswordAuthenticator/' /etc/cassandra/cassandra.yaml
    
    log_info "Enabling CassandraAuthorizer..."
    sed -i 's/authorizer: AllowAllAuthorizer/authorizer: CassandraAuthorizer/' /etc/cassandra/cassandra.yaml
    
    log_info "Ensure network_authorizer is compatible..."
    # Network authorizer will be set to CassandraNetworkAuthorizer in cis_3_5
    
    log_info "Restarting Cassandra..."
    systemctl restart cassandra
    sleep 15
    
    log_info "Verifying authentication..."
    grep -in "authenticator:" /etc/cassandra/cassandra.yaml
    grep -in "authorizer:" /etc/cassandra/cassandra.yaml
    
    log_info "Authentication complete!"
}

#===============================================================================
# CIS 3.1, 3.2, 3.8: Passwords & Roles
#===============================================================================
cis_3_1() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 3.1, 3.2, 3.8: Passwords & Roles${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Changing default password..."
    cqlsh -u cassandra -p cassandra -e "ALTER ROLE 'cassandra' WITH PASSWORD = 'N3wStr0ng@Pass!';"
    
    log_info "Creating cis_admin role..."
    cqlsh -u cassandra -p N3wStr0ng@Pass! -e "CREATE ROLE 'cis_admin' WITH PASSWORD='Adm1n@Secure99!' AND LOGIN=TRUE;"
    
    log_info "Granting permissions..."
    cqlsh -u cassandra -p N3wStr0ng@Pass! -e "GRANT ALL PERMISSIONS ON ALL KEYSPACES TO cis_admin;"
    
    log_info "Making cis_admin a superuser..."
    cqlsh -u cassandra -p N3wStr0ng@Pass! -e "ALTER ROLE 'cis_admin' WITH SUPERUSER=TRUE;"
    
    log_info "Demoting cassandra user (as cis_admin)..."
    cqlsh -u cis_admin -p Adm1n@Secure99! -e "ALTER ROLE 'cassandra' WITH SUPERUSER=FALSE;"
    
    log_info "Verifying roles..."
    cqlsh -u cis_admin -p Adm1n@Secure99! -e "SELECT role, is_superuser FROM system_auth.roles;"
    
    log_info "Passwords & Roles complete!"
}

#===============================================================================
# CIS 3.5, 3.6, 4.2: Network & Audit
#===============================================================================
cis_3_5() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 3.5, 3.6, 4.2: Network & Audit${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Configuring listen address (CIS 3.5)..."
    sed -i 's/^listen_address: 127.0.0.1/listen_address: localhost/' /etc/cassandra/cassandra.yaml
    
    log_info "Enabling network authorizer (CIS 3.6)..."
    sed -i 's/network_authorizer: AllowAllNetworkAuthorizer/network_authorizer: CassandraNetworkAuthorizer/' /etc/cassandra/cassandra.yaml
    
    log_info "Enabling audit logging (CIS 4.2)..."
    sed -i 's/^    enabled: false/    enabled: true/' /etc/cassandra/cassandra.yaml
    
    log_info "Restarting Cassandra..."
    systemctl restart cassandra
    sleep 15
    
    log_info "Verifying network settings..."
    grep -in "listen_address:" /etc/cassandra/cassandra.yaml
    grep -in "network_authorizer:" /etc/cassandra/cassandra.yaml
    
    log_info "Verifying logging..."
    nodetool getlogginglevels 2>/dev/null | grep ROOT || log_warn "nodetool not ready yet"
    
    log_info "Network & Audit complete!"
}

#===============================================================================
# CIS 5.1, 5.2: Encryption
#===============================================================================
cis_5_1() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  CIS 5.1, 5.2: Encryption${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    log_info "Creating SSL directory..."
    mkdir -p /etc/cassandra/ssl
    
    log_info "Generating SSL certificates..."
    keytool -genkey \
        -alias cassandra \
        -keyalg RSA \
        -keysize 2048 \
        -keystore /etc/cassandra/ssl/keystore.jks \
        -storepass cassandra123 \
        -keypass cassandra123 \
        -dname "CN=cassandra, OU=lab, O=lab, L=lab, S=lab, C=US" \
        -validity 365
    
    log_info "Exporting certificate..."
    keytool -export \
        -alias cassandra \
        -file /etc/cassandra/ssl/cassandra.crt \
        -keystore /etc/cassandra/ssl/keystore.jks \
        -storepass cassandra123
    
    log_info "Creating truststore..."
    keytool -import \
        -alias cassandra \
        -file /etc/cassandra/ssl/cassandra.crt \
        -keystore /etc/cassandra/ssl/truststore.jks \
        -storepass cassandra123 \
        -noprompt
    
    log_info "Fixing ownership..."
    chown -R cassandra:cassandra /etc/cassandra/ssl
    
    log_info "Enabling inter-node encryption (CIS 5.1)..."
    sed -i 's/^    internode_encryption: none/    internode_encryption: all/' /etc/cassandra/cassandra.yaml
    sed -i 's|^    keystore: conf/.keystore|    keystore: /etc/cassandra/ssl/keystore.jks|' /etc/cassandra/cassandra.yaml
    sed -i 's|^    keystore_password: cassandra|    keystore_password: cassandra123|' /etc/cassandra/cassandra.yaml
    sed -i 's|^    truststore: conf/.truststore|    truststore: /etc/cassandra/ssl/truststore.jks|' /etc/cassandra/cassandra.yaml
    sed -i 's|^    truststore_password: cassandra|    truststore_password: cassandra123|' /etc/cassandra/cassandra.yaml
    
    log_info "Enabling client encryption (CIS 5.2)..."
    sed -i 's/^    enabled: false/    enabled: true/' /etc/cassandra/cassandra.yaml
    sed -i 's/^    optional: true/    optional: false/' /etc/cassandra/cassandra.yaml
    
    log_info "Restarting Cassandra..."
    systemctl restart cassandra
    sleep 15
    
    log_info "Verifying encryption..."
    grep -in "internode_encryption:" /etc/cassandra/cassandra.yaml
    grep -in "enabled:" /etc/cassandra/cassandra.yaml | head -5
    
    log_info "Encryption complete!"
}

#===============================================================================
# Verification
#===============================================================================
verify_all() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  FINAL VERIFICATION${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    echo ""
    echo -e "${GREEN}CIS 1.1 - User/Group:${NC}"
    getent passwd cassandra
    getent group cassandra
    
    echo ""
    echo -e "${GREEN}CIS 1.2 - Java:${NC}"
    java -version
    
    echo ""
    echo -e "${GREEN}CIS 1.3 - Python:${NC}"
    python3 --version
    
    echo ""
    echo -e "${GREEN}CIS 1.4 - Cassandra:${NC}"
    cassandra -v
    
    echo ""
    echo -e "${GREEN}CIS 1.5 - Non-root:${NC}"
    ps -aef | grep cassandra | grep java | cut -d' ' -f1
    
    echo ""
    echo -e "${GREEN}CIS 1.6 - NTP:${NC}"
    timedatectl status | grep NTP
    
    echo ""
    echo -e "${GREEN}CIS 2.1 - Authenticator:${NC}"
    grep -in "authenticator:" /etc/cassandra/cassandra.yaml | head -1
    
    echo ""
    echo -e "${GREEN}CIS 2.2 - Authorizer:${NC}"
    grep -in "authorizer:" /etc/cassandra/cassandra.yaml | head -1
    
    echo ""
    echo -e "${GREEN}CIS 3.1, 3.8 - Roles:${NC}"
    cqlsh -u cis_admin -p "$CIS_ADMIN_PASSWORD" -e "SELECT role, is_superuser FROM system_auth.roles;"
    
    echo ""
    echo -e "${GREEN}CIS 3.5 - Listen Address:${NC}"
    grep -in "listen_address:" /etc/cassandra/cassandra.yaml | head -1
    
    echo ""
    echo -e "${GREEN}CIS 3.6 - Network Authorizer:${NC}"
    grep -in "network_authorizer:" /etc/cassandra/cassandra.yaml | head -1
    
    echo ""
    echo -e "${GREEN}CIS 4.1 - Logging:${NC}"
    nodetool getlogginglevels | grep ROOT
    
    echo ""
    echo -e "${GREEN}CIS 4.2 - Audit:${NC}"
    grep -A2 "audit_logging_options" /etc/cassandra/cassandra.yaml | head -3
    
    echo ""
    echo -e "${GREEN}CIS 5.1 - Inter-node Encryption:${NC}"
    grep -in "internode_encryption:" /etc/cassandra/cassandra.yaml | head -1
    
    echo ""
    echo -e "${GREEN}CIS 5.2 - Client Encryption:${NC}"
    grep -A1 "client_encryption_options:" /etc/cassandra/cassandra.yaml | head -3
    
    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}  ALL CIS CHECKS COMPLETE!${NC}"
    echo -e "${GREEN}=======================================${NC}"
}

#===============================================================================
# Main Menu
#===============================================================================
main_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}============================================================${NC}"
        echo -e "${BLUE}  CIS Apache Cassandra 4.0 - WSL Native Setup${NC}"
        echo -e "${BLUE}============================================================${NC}"
        echo ""
        echo "  1) CIS Section 1: Installation (1.0 - 1.6)"
        echo "  2) CIS Section 2: Authentication (2.1)"
        echo "  3) CIS Section 3: Authorization (3.1, 3.5, 3.6)"
        echo "  4) CIS Section 4: Logging (4.1, 4.2)"
        echo "  5) CIS Section 5: Encryption (5.1, 5.2)"
        echo ""
        echo "  A) Run ALL CIS (1 - 5)"
        echo "  V) Verify All CIS Checks"
        echo ""
        echo -e "${RED}  Q) Quit${NC}"
        echo ""
        echo -n "Select option: "
        read choice
        
        case $choice in
            1) 
                check_root
                cis_1_0
                cis_1_1
                cis_1_4
                cis_1_6
                cis_1_5
                ;;
            2) cis_2_1 ;;
            3) 
                cis_3_1
                cis_3_5
                ;;
            4) 
                nodetool getlogginglevels 2>/dev/null | grep ROOT || log_warn "Cassandra not running"
                cis_3_5
                ;;
            5) cis_5_1 ;;
            A|a) 
                check_root
                cis_1_0
                cis_1_1
                cis_1_4
                cis_1_6
                cis_1_5
                cis_2_1
                cis_3_1
                cis_3_5
                cis_5_1
                verify_all
                ;;
            V|v) verify_all ;;
            Q|q) 
                echo "Goodbye!"
                exit 0
                ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

if [ "$EUID" -ne 0 ]; then
    log_warn "Running without root - some options may fail"
fi

main_menu
