# Post-Deploy Guide

This guide starts from a fresh Terraform deployment and assumes the cluster is already provisioned.

## 1. Copy the SSH key to the master node

From your local machine, copy the private key to the master node. The master is the jump host for the private `10.0.1.x` Cassandra nodes.

```bash
scp -i ssh/cis_key ssh/cis_key cassandra@20.214.152.93:/home/cassandra/.ssh/cis_key
```

On the master node, fix the permissions and create an SSH config so the key is used automatically for the DB nodes:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/cis_key
cat > ~/.ssh/config <<'EOF'
Host db1 10.0.1.11
  HostName 10.0.1.11
  User cassandra
  IdentityFile ~/.ssh/cis_key
  IdentitiesOnly yes

Host db2 10.0.1.12
  HostName 10.0.1.12
  User cassandra
  IdentityFile ~/.ssh/cis_key
  IdentitiesOnly yes

Host db3 10.0.1.13
  HostName 10.0.1.13
  User cassandra
  IdentityFile ~/.ssh/cis_key
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config
```

After that, the master can reach the DB nodes with simple hostnames:

```bash
ssh db1
ssh db2
ssh db3
```

If you prefer to test first, use:

```bash
ssh -i ~/.ssh/cis_key cassandra@10.0.1.11
```

## 2. Clone the CIS test repo

Clone the test repository on the master node, then enter it:

```bash
git clone https://github.com/Triggermetric/cis-test
cd cis-test
```

If you already cloned it before, just update it:

```bash
git pull
```

## 3. Run CIS audit / harden / verify

The repository’s CIS tooling is expected to live on the master under `/opt/cis` after deployment. Use the tool from there.

Typical workflow:

```bash
chmod 744 cis-tool.sh
chmod 744 run_backend.sh
chmod 744 run_frontend.sh

cd ./scripts
sudo ./cis-tool.sh cluster audit
sudo ./cis-tool.sh cluster harden
sudo ./cis-tool.sh cluster verify
```

If your deployment exposes a different wrapper or script entry point, use that same sequence from the deployed CIS scripts directory.

## 4. Start backend and frontend

Use the repo scripts from your workstation or the master, depending on where you run the services.

Backend:

```bash
sudo bash scripts/run_backend.sh
```

Frontend:

```bash
sudo bash scripts/run_frontend.sh
```

If you launch them manually, these are the equivalent local commands:

```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --ws wsproto
```

```bash
cd frontend
npm run dev -- --host 0.0.0.0
```

## 5. What to check after deploy

### Cassandra nodes

On the master, verify you can reach the DB nodes and that Cassandra is healthy:

```bash
ssh db1
nodetool status
cqlsh -u cassandra -p cassandra 127.0.0.1 -e "DESC KEYSPACES;"
```

Useful role checks:

```bash
cqlsh -u cassandra -p cassandra 127.0.0.1 -e "SELECT role, can_login, member_of FROM system_auth.roles;"
cqlsh -u cassandra -p cassandra 127.0.0.1 -e "SELECT role, is_superuser FROM system_auth.roles;"
cqlsh -u cassandra -p cassandra 127.0.0.1 -e "SELECT * FROM system_auth.role_permissions;"
```

### Backend

Check the backend health and logs:

```bash
curl http://127.0.0.1:8000/docs
journalctl -u backend -f
```

If you are running it in a terminal, watch for startup errors about Cassandra auth or missing keyspace.

### Frontend

Open the frontend URL printed by Vite, usually:

```text
http://127.0.0.1:5173
```

## 6. Troubleshooting

### SSH to DB nodes fails

- Confirm the key exists on the master: `ls -l ~/.ssh/cis_key`
- Confirm permissions: `chmod 600 ~/.ssh/cis_key`
- Confirm the SSH config points to the private IPs `10.0.1.11`, `10.0.1.12`, `10.0.1.13`
- Test with verbose SSH:

```bash
ssh -v db1
```

### Cassandra auth errors

If you see `Invalid metadata has been detected for role cassandra`, check:

```bash
sudo tail -100 /var/log/cassandra/system.log
cqlsh -u cassandra -p cassandra 127.0.0.1 -e "SELECT * FROM system_auth.roles;"
```

If needed, restart the node and re-check cluster status:

```bash
sudo systemctl restart cassandra
nodetool status
```

### Backend cannot connect to Cassandra

- Confirm the backend environment variables:

```bash
echo "$CASSANDRA_CONTACT_POINTS"
echo "$CIS_ADMIN_USER"
echo "$CIS_ADMIN_PASS"
```

- Confirm the backend log shows a working Cassandra session.
- Verify the keyspace exists:

```bash
cqlsh -u cassandra -p cassandra 127.0.0.1 -e "DESCRIBE KEYSPACES;"
```

### Cluster audit scripts fail

- Make sure `/opt/cis/cis-tool.sh` exists.
- Check the deployed script permissions:

```bash
ls -l /opt/cis/cis-tool.sh
```

- Review the remote deploy log or run the script again with tracing if needed.

## 7. Quick reference

```bash
ssh cassandra@<MASTER_PUBLIC_IP>
ssh db1
cd /opt/cis
sudo ./cis-tool.sh cluster audit
sudo ./cis-tool.sh cluster harden
sudo ./cis-tool.sh cluster verify
sudo bash scripts/run_backend.sh
sudo bash scripts/run_frontend.sh
```

If you want a cleaner day-2 workflow, keep the master SSH config in place and always jump to the DB nodes through `db1`, `db2`, and `db3`.
