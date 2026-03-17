# CIS Apache Cassandra 4.0 Benchmark Setup Guide

## Overview

This guide walks you through setting up a hardened Apache Cassandra 4.0 environment following CIS benchmarks. Each phase includes verification steps to ensure success.

---

## PHASE 1 — WSL2 Setup

### Step 1.1: Install WSL2 with Ubuntu

**Action:** Open PowerShell as Administrator and run:

```powershell
wsl --install
```

**Expected:** Ubuntu will be installed automatically. Restart your PC when prompted.

**Post-restart:** Ubuntu terminal will open. Create your username/password when asked.

---

### Step 1.2: Verify WSL2 Version

**Action:** In PowerShell or CMD:

```powershell
wsl --list --verbose
```

**Expected Output:**

```
  NAME                   STATE           VERSION
* Ubuntu                 Running         2
```

**If VERSION shows 1**, upgrade to 2:

```powershell
wsl --set-version Ubuntu 2
```

---

## PHASE 2 — System Updates

### Step 2.1: Update Ubuntu Packages

**Action:** In Ubuntu terminal:

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

**Expected:** Terminal will show download and installation progress. Wait for completion.

**Verify:**

```bash
sudo apt-get update
# Should complete without errors
```

---

## PHASE 3 — Install Prerequisites

### Step 3.1: Install Java 8 (CIS Rec 1.2)

**Action:**

```bash
sudo apt-get install openjdk-8-jdk -y
```

**Verify:**

```bash
java -version
```

**Expected Output:**

```
openjdk version "1.8.0_xxx"
OpenJDK Runtime Environment (build 1.8.0_xxx-bxx)
OpenJDK 64-Bit Server VM (build 25.xxx-bxx, mixed mode)
```

**Set JAVA_HOME (optional but recommended):**

```bash
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> ~/.bashrc
source ~/.bashrc
```

---

### Step 3.2: Install Python 3 (CIS Rec 1.3)

**Action:**

```bash
sudo apt-get install python3 python3-pip -y
python3.9 --version

export CQLSH_PYTHON=/usr/bin/python3.9
```

**Verify:**

```bash
python3 --version
```

**Expected Output:**

```
Python 3.x.x
```

---

## PHASE 4 — Create Dedicated User/Group (CIS Rec 1.1, 1.5, 3.4)

> ⚠️ **IMPORTANT:** Do this BEFORE installing Cassandra.

### Step 4.1: Create cassandra group

**Action:**

```bash
sudo groupadd cassandra
```

**Verify:**

```bash
getent group cassandra
```

**Expected Output:**

```
cassandra:x:1000:
```

---

### Step 4.2: Create cassandra user

**Action:**

```bash
sudo useradd -m -d /home/cassandra -s /bin/bash -g cassandra -u 2000 cassandra
```

**Verify:**

```bash
getent passwd cassandra
```

**Expected Output:**

```
cassandra:x:2000:1000::/home/cassandra:/bin/bash
```

---

### Step 4.3: Set password for cassandra user

**Action:**

```bash
sudo passwd cassandra
# Enter a strong password when prompted
```

---

## PHASE 5 — Install Apache Cassandra (CIS Rec 1.4)

### Step 5.1: Add Cassandra Repository

**Action:**

```bash
# Install prerequisites
sudo apt-get install curl gnupg -y

# Add Apache Cassandra apt repo key
curl https://downloads.apache.org/cassandra/KEYS | sudo gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg

# Add the repo
echo "deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://debian.cassandra.apache.org 40x main" \
  | sudo tee /etc/apt/sources.list.d/cassandra.sources.list
```

**Verify:**

```bash
cat /etc/apt/sources.list.d/cassandra.sources.list
```

**Expected Output:**

```
deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://debian.cassandra.apache.org 40x main
```

---

### Step 5.2: Install Cassandra

**Action:**

```bash
sudo apt-get update
sudo apt-get install cassandra -y
```

**Verify:**

```bash
cassandra -v
```

**Expected Output:**

```
4.0.x
```

---

### Step 5.3: Fix Directory Ownership

**Action:**

```bash
sudo chown -R cassandra:cassandra /var/lib/cassandra
sudo chown -R cassandra:cassandra /var/log/cassandra
sudo chown -R cassandra:cassandra /etc/cassandra
```

**Verify:**

```bash
ls -ld /var/lib/cassandra /var/log/cassandra /etc/cassandra
```

**Expected:** All should show `cassandra:cassandra` ownership.

---

## PHASE 6 — Clock Synchronization (CIS Rec 1.6)

### Step 6.1: Enable NTP

**Action:**

```bash
sudo apt-get install ntp -y
sudo timedatectl set-ntp true
```

**Verify:**

```bash
timedatectl status
```

**Expected Output:**

```
               Local time: Tue 2026-03-17 xx:xx:xx
           Universal time: Tue 2026-03-17 xx:xx:xx
                 RTC time: Tue 2026-03-17 xx:xx:xx
                Time zone: ...
                    NTP enabled: yes
                NTP synchronized: yes
```

---

## PHASE 7 — Start Cassandra

### Step 7.1: Start Cassandra as cassandra user

> ⚠️ Cassandra must run as the `cassandra` user (not root) for CIS compliance.

**Action:**

```bash
sudo -u cassandra cassandra -f &
```

**Wait 30 seconds for startup, then verify:**

**Verify process owner:**

```bash
ps -aef | grep cassandra | grep java
```

**Expected Output:**

```
cassandra  1234  1233  0  xx:xx ?        00:00:00 /usr/bin/java ... org.apache.cassandra.service.CassandraDaemon
```

> Note: The first column should show `cassandra`, NOT `root`.

**Verify port is listening:**

```bash
sudo netstat -tlnp | grep 9042
```

**Expected Output:**

```
tcp        0      0 127.0.0.1:9042          0.0.0.0:*               LISTEN      1234/java
```

---

## PHASE 8 — Authentication & Authorization (CIS Rec 2.1, 2.2)

### Step 8.1: Configure Password Authentication

**Action:**

```bash
sudo nano /etc/cassandra/cassandra.yaml
```

Find and change these values:

| Setting         | Original              | Change To             |
| --------------- | --------------------- | --------------------- |
| `authenticator` | AllowAllAuthenticator | PasswordAuthenticator |
| `authorizer`    | AllowAllAuthorizer    | CassandraAuthorizer   |

**Quick search in nano:** Press `Ctrl+W`, type `authenticator`, press Enter.

**Save:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

### Step 8.2: Restart Cassandra

**Action:**

```bash
sudo systemctl restart cassandra
```

**Wait 30 seconds, then verify:**

```bash
grep -in "authenticator:" /etc/cassandra/cassandra.yaml
grep -in "authorizer:" /etc/cassandra/cassandra.yaml
```

**Expected Output:**

```
authenticator: PasswordAuthenticator
authorizer: CassandraAuthorizer
```

---

## PHASE 9 — Initial Connection & Password Management (CIS Rec 3.2)

### Step 9.1: Connect with Default Credentials

**Action:**

```bash
cqlsh -u cassandra -p cassandra
```

**Expected:** You should see the CQLSH prompt:

```
Connected to cis-cluster at 127.0.0.1:9042
[cqlsh 6.x | Cassandra 4.0.x | CQL spec 3.4 | Native protocol v4]
Use HELP for help.
cassandra@cqlsh>
```

---

### Step 9.2: Change Default Password

**In cqlsh, run:**

```sql
ALTER ROLE 'cassandra' WITH PASSWORD = 'N3wStr0ng@Pass!';
```

**Expected Output:**

```
<no output> - command completed successfully
```

---

### Step 9.3: Verify Old Password Fails

**Action:** Exit cqlsh (`exit` or `Ctrl+D`), then try:

```bash
cqlsh -u cassandra -p cassandra
```

**Expected:** Connection should FAIL with authentication error.

---

## PHASE 10 — Create Admin Role (CIS Rec 3.1)

### Step 10.1: Connect with New Password

**Action:**

```bash
cqlsh -u cassandra -p 'N3wStr0ng@Pass!'
```

---

### Step 10.2: Create Admin User

**In cqlsh, run:**

```sql
CREATE ROLE 'cis_admin' WITH PASSWORD='Adm1n@Secure99!' AND LOGIN=TRUE AND SUPERUSER=TRUE;
GRANT ALL PERMISSIONS ON ALL KEYSPACES TO cis_admin;
```

**Expected Output:**

```
<no output>
```

---

### Step 10.3: Verify New Admin Works

**Action:** Exit and reconnect:

```bash
cqlsh -u cis_admin -p 'Adm1n@Secure99!'
```

---

### Step 10.4: Demote Default cassandra User

**In cqlsh (as cis_admin), run:**

```sql
ALTER ROLE cassandra WITH SUPERUSER = false;
```

---

### Step 10.5: Verify Roles

**In cqlsh, run:**

```sql
SELECT role, is_superuser FROM system_auth.roles ALLOW FILTERING;
```

**Expected Output:**

```
 role       | is_superuser
------------+--------------
     cis_admin |          True
     cassandra |         False
(2 rows)
```

---

## PHASE 11 — Review Roles & Permissions (CIS Rec 3.3, 3.7)

### Step 11.1: List All Roles

**In cqlsh, run:**

```sql
LIST ROLES;
```

---

### Step 11.2: Review Permissions

**In cqlsh, run:**

```sql
SELECT * FROM system_auth.role_permissions;
```

---

### Step 11.3: Check Login Abilities

**In cqlsh, run:**

```sql
SELECT role, can_login, member_of FROM system_auth.roles;
```

**Expected:** Should only show `cassandra` and `cis_admin` with correct settings.

---

## PHASE 12 — Network Configuration (CIS Rec 3.5)

### Step 12.1: Set Listen Address

**Action:**

```bash
sudo nano /etc/cassandra/cassandra.yaml
```

Find and change:

```yaml
listen_address: 127.0.0.1
```

To:

```yaml
listen_address: localhost
```

**Save:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

### Step 12.2: Restart and Verify

**Action:**

```bash
sudo systemctl restart cassandra
```

**Wait 30 seconds, then verify:**

```bash
grep -in "listen_address:" /etc/cassandra/cassandra.yaml
```

**Expected Output:**

```
listen_address: 127.0.0.1
```

---

## PHASE 13 — Network Authorization (CIS Rec 3.6)

### Step 13.1: Enable Network Authorizer

**Action:**

```bash
sudo nano /etc/cassandra/cassandra.yaml
```

Find and change:

```yaml
# network_authorizer: AllowAllNetworkAuthorizer
```

To:

```yaml
network_authorizer: CassandraNetworkAuthorizer
```

**Save:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

### Step 13.2: Restart and Verify

**Action:**

```bash
sudo systemctl restart cassandra
```

**Verify:**

```bash
grep -in "network_authorizer:" /etc/cassandra/cassandra.yaml
```

**Expected Output:**

```
network_authorizer: CassandraNetworkAuthorizer
```

---

## PHASE 14 — Logging (CIS Rec 4.1)

### Step 14.1: Check Current Logging Levels

**Action:**

```bash
nodetool getlogginglevels
```

**Expected Output:**

```
Logger Name                                        | Level
---------------------------------------------------------
ROOT                                               | INFO
...
```

> ROOT should show INFO, not OFF.

---

### Step 14.2: Configure Logging (if needed)

**Action:**

```bash
sudo nano /etc/cassandra/logback.xml
```

Ensure root logger is set to INFO:

```xml
<root level="INFO">
  <appender-ref ref="STDOUT" />
</root>
```

**Restart and verify:**

```bash
sudo systemctl restart cassandra
nodetool getlogginglevels | grep "^ROOT"
```

---

## PHASE 15 — Audit Logging (CIS Rec 4.2)

### Step 15.1: Enable Audit Logging

**Action:**

```bash
sudo nano /etc/cassandra/cassandra.yaml
```

Find and modify:

```yaml
# audit_logging_options:
#    enabled: false
```

To:

```yaml
audit_logging_options:
  enabled: true
```

**Save:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

### Step 15.2: Restart and Verify

**Action:**

```bash
sudo systemctl restart cassandra
```

**Wait 30 seconds, then verify:**

```bash
grep -A2 "audit_logging_options:" /etc/cassandra/cassandra.yaml
```

**Expected Output:**

```
audit_logging_options:
   enabled: true
```

---

## PHASE 16 — SSL/TLS Encryption Setup

### Step 16.1: Create SSL Directory

**Action:**

```bash
sudo mkdir -p /etc/cassandra/ssl
cd /etc/cassandra/ssl
```

---

### Step 16.2: Generate Keystore

**Action:**

```bash
sudo keytool -genkey \
  -alias cassandra \
  -keyalg RSA \
  -keysize 2048 \
  -keystore keystore.jks \
  -storepass cassandra123 \
  -keypass cassandra123 \
  -dname "CN=cassandra, OU=lab, O=lab, L=lab, S=lab, C=US" \
  -validity 365
```

**Verify:**

```bash
ls -la /etc/cassandra/ssl/
```

---

### Step 16.3: Export Certificate

**Action:**

```bash
sudo keytool -export \
  -alias cassandra \
  -file /etc/cassandra/ssl/cassandra.crt \
  -keystore /etc/cassandra/ssl/keystore.jks \
  -storepass cassandra123
```

---

### Step 16.4: Create Truststore

**Action:**

```bash
sudo keytool -import \
  -alias cassandra \
  -file /etc/cassandra/ssl/cassandra.crt \
  -keystore /etc/cassandra/ssl/truststore.jks \
  -storepass cassandra123 \
  -noprompt
```

---

### Step 16.5: Fix Ownership

**Action:**

```bash
sudo chown -R cassandra:cassandra /etc/cassandra/ssl
```

**Verify:**

```bash
ls -la /etc/cassandra/ssl/
```

---

## PHASE 17 — Enable Inter-Node Encryption (CIS Rec 5.1)

### Step 17.1: Configure Server Encryption

**Action:**

```bash
sudo nano /etc/cassandra/cassandra.yaml
```

Find and modify `server_encryption_options`:

```yaml
server_encryption_options:
  internode_encryption: all
  keystore: /etc/cassandra/ssl/keystore.jks
  keystore_password: cassandra123
  truststore: /etc/cassandra/ssl/truststore.jks
  truststore_password: cassandra123
```

**Save:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

### Step 17.2: Restart and Verify

**Action:**

```bash
sudo systemctl restart cassandra
```

**Verify:**

```bash
grep -in "internode_encryption:" /etc/cassandra/cassandra.yaml
```

**Expected Output:**

```
internode_encryption: all
```

---

## PHASE 18 — Enable Client Encryption (CIS Rec 5.2)

### Step 18.1: Configure Client Encryption

**Action:**

```bash
sudo nano /etc/cassandra/cassandra.yaml
```

Find and modify `client_encryption_options`:

```yaml
client_encryption_options:
  enabled: true
  optional: false
  keystore: /etc/cassandra/ssl/keystore.jks
  keystore_password: cassandra123
  truststore: /etc/cassandra/ssl/truststore.jks
  truststore_password: cassandra123
```

**Save:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

### Step 18.2: Restart Cassandra

**Action:**

```bash
sudo systemctl restart cassandra
```

**Wait 30 seconds**

---

### Step 18.3: Test Connection WITH SSL

**Action:**

```bash
cqlsh -u cis_admin -p 'Adm1n@Secure99!' --ssl
```

**Expected:** Should connect successfully.

**If connection fails with SSL error**, specify truststore:

```bash
cqlsh -u cis_admin -p 'Adm1n@Secure99!' \
  --ssl \
  --truststore /etc/cassandra/ssl/truststore.jks \
  --truststore-password cassandra123
```

---

## PHASE 19 — Final Verification Checklist

Run all these commands to verify your setup:

### User & Group (CIS 1.1, 1.5, 3.4)

```bash
getent passwd | grep cassandra
getent group | cassandra
ps -aef | grep cassandra | grep java | cut -d' ' -f1
# Expected: cassandra (NOT root)
```

### Java & Python (CIS 1.2, 1.3)

```bash
java -version
python3 --version
```

### Cassandra Version (CIS 1.4)

```bash
cassandra -v
# Expected: 4.0.x
```

### Clock Sync (CIS 1.6)

```bash
timedatectl status | grep NTP
# Expected: NTP enabled: yes
```

### Authentication (CIS 2.1, 2.2)

```bash
grep -in "authenticator:" /etc/cassandra/cassandra.yaml
grep -in "authorizer:" /etc/cassandra/cassandra.yaml
# Expected: PasswordAuthenticator, CassandraAuthorizer
```

### Admin Role (CIS 3.1)

```bash
cqlsh -u cis_admin -p 'Adm1n@Secure99!' -e "SELECT role, is_superuser FROM system_auth.roles ALLOW FILTERING;"
```

### Network (CIS 3.5, 3.6)

```bash
grep -in "listen_address:" /etc/cassandra/cassandra.yaml
grep -in "network_authorizer:" /etc/cassandra/cassandra.yaml
```

### Logging (CIS 4.1)

```bash
nodetool getlogginglevels | grep "^ROOT"
# Expected: INFO
```

### Audit Logging (CIS 4.2)

```bash
grep -A2 "audit_logging_options:" /etc/cassandra/cassandra.yaml
# Expected: enabled: true
```

### Encryption (CIS 5.1, 5.2)

```bash
grep -in "internode_encryption:" /etc/cassandra/cassandra.yaml
grep -A3 "client_encryption_options:" /etc/cassandra/cassandra.yaml | grep -v "#"
# Expected: all, enabled: true
```

---

## Troubleshooting

### Cassandra won't start

```bash
# Check logs
sudo journalctl -u cassandra -n 50
# Or
cat /var/log/cassandra/system.log
```

### Port already in use

```bash
sudo netstat -tlnp | grep 9042
# Kill existing process if needed
sudo kill <PID>
```

### SSL connection issues

```bash
# If you want to temporarily disable SSL for testing:
# 1. Set optional: true in client_encryption_options
# 2. Restart Cassandra
# 3. Connect without --ssl flag
```

### Reset everything and start fresh

```powershell
# In PowerShell (NOT in WSL):
wsl --unregister Ubuntu
wsl --install -d Ubuntu
# Then follow this guide from Phase 3
```

---

## Quick Reference: Connection Commands

| Scenario                      | Command                                                                                                                           |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Connect without SSL           | `cqlsh -u cis_admin -p 'Adm1n@Secure99!'`                                                                                         |
| Connect with SSL              | `cqlsh -u cis_admin -p 'Adm1n@Secure99!' --ssl`                                                                                   |
| Connect with SSL + Truststore | `cqlsh -u cis_admin -p 'Adm1n@Secure99!' --ssl --truststore /etc/cassandra/ssl/truststore.jks --truststore-password cassandra123` |
| Connect to specific host/port | `cqlsh -h 127.0.0.1 -p 9042 -u cis_admin -p 'Adm1n@Secure99!' --ssl`                                                              |
