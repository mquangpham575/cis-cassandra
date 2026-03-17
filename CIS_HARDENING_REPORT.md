# CIS Apache Cassandra 4.0 Benchmark v1.3.0 - Hardening Report

## Executive Summary

This document provides a comprehensive breakdown of CIS Apache Cassandra 4.0 Benchmark recommendations, classifying each as **Manual** or **Automated**, with verification commands for a **3-node cluster** deployment.

**Cluster Configuration:**
- Node 1: cassandra-node1 (172.18.0.11)
- Node 2: cassandra-node2 (172.18.0.12)
- Node 3: cassandra-node3 (172.18.0.13)

---

## Quick Start

### Prerequisites
```bash
# Install Docker
sudo apt-get install docker.io

# Clone/Setup project
cd cis-cassandra
chmod +x scripts/*.sh
```

### Execution Order
```bash
# 1. Deploy 3-node cluster
./scripts/setup_3node_cluster.sh

# 2. Apply CIS hardening
./scripts/deploy_cis_config.sh

# 3. Run automated audit
./scripts/audit_cis_compliance.sh
```

---

## CIS Recommendations Classification

### Legend
| Symbol | Meaning |
|--------|---------|
| ✅ | Automated check available |
| ⚠️ | Manual verification required |
| 🔧 | Configuration step required |

---

## Section 1: Installation & Configuration

| ID | Recommendation | Type | Automated Check | Verification Command |
|----|---------------|------|-----------------|----------------------|
| 1.1 | Dedicated user/group for Cassandra | ⚠️ Manual | N/A | `getent passwd \| grep cassandra` |
| 1.2 | Ensure Java is installed | ✅ Auto | ✅ | `docker exec cassandra-node1 java -version` |
| 1.3 | Ensure Python is installed | ✅ Auto | ✅ | `docker exec cassandra-node1 python3 --version` |
| 1.4 | Install Cassandra from package | ⚠️ Manual | N/A | `docker exec cassandra-node1 cassandra -v` |
| 1.5 | Run Cassandra as non-root user | ✅ Auto | ✅ | `docker exec cassandra-node1 ps -u cassandra -f \| grep java` |
| 1.6 | Ensure NTP is enabled | ✅ Auto | ✅ | `docker exec cassandra-node1 timedatectl \| grep NTP` |

**Verification for all nodes:**
```bash
# 1.1 - User/Group
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  docker exec $node getent passwd | grep cassandra
  docker exec $node getent group | grep cassandra
done

# 1.2 - Java
docker exec cassandra-node1 java -version

# 1.3 - Python
docker exec cassandra-node1 python3 --version

# 1.4 - Cassandra version
docker exec cassandra-node1 cassandra -v

# 1.5 - Non-root process
docker exec cassandra-node1 ps -u cassandra -f | grep java

# 1.6 - NTP
docker exec cassandra-node1 timedatectl status
```

---

## Section 2: Authentication & Authorization

| ID | Recommendation | Type | Automated Check | Verification Command |
|----|---------------|------|-----------------|----------------------|
| 2.1 | Enable PasswordAuthenticator | 🔧 Config | ✅ | `grep 'authenticator: PasswordAuthenticator' /etc/cassandra/cassandra.yaml` |
| 2.2 | Enable CassandraAuthorizer | 🔧 Config | ✅ | `grep 'authorizer: CassandraAuthorizer' /etc/cassandra/cassandra.yaml` |

**Verification for all nodes:**
```bash
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  echo "=== $node ==="
  docker exec $node grep 'authenticator: PasswordAuthenticator' /etc/cassandra/cassandra.yaml
  docker exec $node grep 'authorizer: CassandraAuthorizer' /etc/cassandra/cassandra.yaml
done
```

---

## Section 3: Authorization & Role Management

| ID | Recommendation | Type | Automated Check | Verification Command |
|----|---------------|------|-----------------|----------------------|
| 3.1 | Create dedicated superuser | 🔧 Config | ✅ | `LIST ROLES; -- Check for non-cassandra superuser` |
| 3.2 | Change default password | 🔧 Config | ✅ | `SELECT role FROM system_auth.roles;` |
| 3.3 | Review roles | ⚠️ Manual | N/A | `SELECT * FROM system_auth.role_permissions;` |
| 3.4 | Non-root user ownership | ⚠️ Manual | ✅ | `id cassandra` |
| 3.5 | Restrict network listen address | 🔧 Config | ✅ | `grep 'listen_address:' /etc/cassandra/cassandra.yaml` |
| 3.6 | Enable network authorizer | 🔧 Config | ✅ | `grep 'network_authorizer:' /etc/cassandra/cassandra.yaml` |
| 3.7 | Review role permissions | ⚠️ Manual | N/A | `SELECT * FROM system_auth.role_permissions;` |
| 3.8 | Remove superuser from default account | 🔧 Config | ✅ | `SELECT role, is_superuser FROM system_auth.roles;` |

**Verification for all nodes:**
```bash
# 3.1 - Dedicated superuser exists
docker exec cassandra-node1 cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e "SELECT role, is_superuser FROM system_auth.roles ALLOW FILTERING;"

# 3.2 - Default password changed
docker exec cassandra-node1 cqlsh -u cassandra -p 'N3wStr0ng@Pass!' -e "SELECT * FROM system_auth.roles;"

# 3.5 - Listen address
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  docker exec $node grep 'listen_address:' /etc/cassandra/cassandra.yaml
done

# 3.6 - Network authorizer
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  docker exec $node grep 'network_authorizer:' /etc/cassandra/cassandra.yaml
done

# 3.8 - Remove cassandra superuser
docker exec cassandra-node1 cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e "SELECT role, is_superuser FROM system_auth.roles WHERE role='cassandra' ALLOW FILTERING;"
```

---

## Section 4: Auditing & Logging

| ID | Recommendation | Type | Automated Check | Verification Command |
|----|---------------|------|-----------------|----------------------|
| 4.1 | Enable logging | 🔧 Config | ✅ | `nodetool getlogginglevels` |
| 4.2 | Enable audit logging | 🔧 Config | ✅ | `grep -A2 'audit_logging_options:' /etc/cassandra/cassandra.yaml` |

**Verification for all nodes:**
```bash
# 4.1 - Logging levels
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  echo "=== $node ==="
  docker exec $node nodetool getlogginglevels
done

# 4.2 - Audit logging
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  echo "=== $node ==="
  docker exec $node grep -A2 'audit_logging_options:' /etc/cassandra/cassandra.yaml
done
```

---

## Section 5: Encryption

| ID | Recommendation | Type | Automated Check | Verification Command |
|----|---------------|------|-----------------|----------------------|
| 5.1 | Enable inter-node encryption | 🔧 Config | ✅ | `grep 'internode_encryption:' /etc/cassandra/cassandra.yaml` |
| 5.2 | Enable client encryption | 🔧 Config | ✅ | `grep -A1 'client_encryption_options:' /etc/cassandra/cassandra.yaml` |

**Verification for all nodes:**
```bash
# 5.1 - Inter-node encryption
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  echo "=== $node ==="
  docker exec $node grep 'internode_encryption:' /etc/cassandra/cassandra.yaml
done

# 5.2 - Client encryption
for node in cassandra-node1 cassandra-node2 cassandra-node3; do
  echo "=== $node ==="
  docker exec $node grep -A3 'client_encryption_options:' /etc/cassandra/cassandra.yaml | grep -v '^#'
done
```

---

## Cluster Verification Commands

### Check cluster status (all 3 nodes)
```bash
docker exec cassandra-node1 nodetool status
# Expected: 3 nodes showing UN (Up/Normal)
```

### Check cluster information
```bash
docker exec cassandra-node1 nodetool describecluster
```

### Verify all nodes respond to CQL
```bash
docker exec cassandra-node1 cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e "SELECT * FROM system_auth.roles;"
docker exec cassandra-node2 cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e "SELECT * FROM system_auth.roles;"
docker exec cassandra-node3 cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e "SELECT * FROM system_auth.roles;"
```

---

## Summary Table

| Section | Total | Automated | Manual | Config Required |
|---------|-------|-----------|--------|-----------------|
| 1. Installation | 6 | 3 | 3 | 0 |
| 2. Authentication | 2 | 0 | 0 | 2 |
| 3. Authorization | 8 | 5 | 3 | 0 |
| 4. Logging | 2 | 0 | 0 | 2 |
| 5. Encryption | 2 | 0 | 0 | 2 |
| **Total** | **20** | **8** | **6** | **6** |

---

## Automated Audit Script Usage

Run the full automated audit:
```bash
cd scripts
./audit_cis_compliance.sh
```

Expected output:
```
==========================================
  CIS Cassandra 4.0 Automated Audit
==========================================
Date: Tue Mar 17 2026

CIS Section: 3-Node Cluster Verification
[PASS] Node cassandra-node1 is running
[PASS] Node cassandra-node2 is running
[PASS] Node cassandra-node3 is running
[PASS] Cluster has 3 nodes

... (all CIS checks) ...

AUDIT SUMMARY

Total Checks: 20
Passed: X
Failed: X
Manual Review: X
```

---

## References

- CIS Apache Cassandra 4.0 Benchmark v1.3.0
- Apache Cassandra Documentation: https://cassandra.apache.org/doc/latest/
- Docker Cassandra Image: https://hub.docker.com/_/cassandra

---

*Report generated for educational purposes - CIS Hardening Lab*
