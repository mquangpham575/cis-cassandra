# CIS Apache Cassandra 4.0 — DevSecOps Compliance Platform

> NT542.Q22 DevSecOps — Group Project  
> CIS Apache Cassandra 4.0 Benchmark v1.3.0 — Full automation across a 3-node cluster

[![CI](https://github.com/<org>/cis-cassandra/actions/workflows/cis-audit.yml/badge.svg)](https://github.com/<org>/cis-cassandra/actions/workflows/cis-audit.yml)

---

## What This Project Does

This platform automatically **audits**, **hardens**, and **monitors** a 3-node Apache Cassandra 4.0 cluster against every recommendation in the CIS Benchmark v1.3.0.

| Layer | Technology | Purpose |
|---|---|---|
| **Cluster** | 3 × Ubuntu 22.04 VMs | Cassandra nodes at `10.0.1.11–13` |
| **Hardening** | Bash scripts (`scripts/`) | Automated CIS audit + remediation for all 5 sections |
| **Backend API** | FastAPI + Python 3.12 | SSH orchestration, JSON audit results, SSE streaming |
| **Dashboard** | React 18 + Vite + Tailwind | Compliance view + live Grafana monitoring |
| **Observability** | Prometheus + Grafana | JMX metrics, latency, heap, GC |
| **CI/CD** | GitHub Actions | 4-job pipeline: lint → test → build → SAST |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Browser / Demo                        │
│   React Dashboard  ←→  FastAPI Backend (port 8000)      │
│   Compliance Tab       /api/audit/*  /api/harden/*       │
│   Monitoring Tab       /api/cluster/status               │
└──────────────────┬──────────────────┬───────────────────┘
                   │ SSH              │ HTTP/SSE
         ┌─────────▼──────────────────▼─────────┐
         │          3-Node Cassandra Cluster      │
         │   node1: 10.0.1.11  (seed)         │
         │   node2: 10.0.1.12                 │
         │   node3: 10.0.1.13                 │
         │                                         │
         │   JMX Exporter :9404 ──► Prometheus    │
         │                           ──► Grafana   │
         └─────────────────────────────────────────┘
```

---

## CIS Benchmark Coverage

| Section | Topic | Checks | Automated |
|---|---|---|---|
| **1** | Installation & OS Hardening | 6 | ✅ |
| **2** | Authentication | 4 | ✅ |
| **3** | Authorization & Access Control | 5 | ✅ |
| **4** | Logging & Auditing | 3 | ✅ |
| **5** | Encryption (TLS) | 2 | ✅ |
| **Total** | | **20** | **20/20** |

---

## Quick Start

### 1. VM Setup (Member 1 — Infrastructure)

```bash
# On each VM (10.0.1.11, .12, .13) — Ubuntu 22.04
sudo apt-get update && sudo apt-get install -y openjdk-8-jdk python3.10

# Install Cassandra 4.0
echo "deb https://debian.cassandra.apache.org 40x main" \
  | sudo tee /etc/apt/sources.list.d/cassandra.sources.list
sudo apt-get update && sudo apt-get install -y cassandra=4.0.19

# SSH key auth for the backend (run on controller node)
ssh-keygen -t ed25519 -f ~/.ssh/cis_key -N ""
ssh-copy-id -i ~/.ssh/cis_key.pub cassandra@10.0.1.11
ssh-copy-id -i ~/.ssh/cis_key.pub cassandra@10.0.1.12
ssh-copy-id -i ~/.ssh/cis_key.pub cassandra@10.0.1.13
```

### 2. Run CIS Hardening Scripts (Member 2 — Scripting)

```bash
# On each node — run as root
sudo bash scripts/cis-tool.sh audit all      # See current state (JSON output)
sudo bash scripts/cis-tool.sh harden all     # Apply all CIS remediations
sudo bash scripts/cis-tool.sh audit all      # Verify: all checks should pass

# Run against a specific section only
sudo bash scripts/cis-tool.sh audit 2        # Section 2: Authentication only
sudo bash scripts/cis-tool.sh harden 5       # Section 5: TLS only

# Dry-run mode (shows what would change, no writes)
sudo bash scripts/cis-tool.sh harden all --dry-run
```

**Bash unit tests (31 assertions):**
```bash
bash scripts/tests/test_audit.sh
# Expected: 31 PASS, 0 FAIL
```

### 3. Start the Backend API (Member 3 — Backend)

```bash
cd backend
cp .env.example .env
# Edit .env: set NODE_IPS, CIS_SSH_KEY, CIS_SSH_USER

pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# API docs: http://10.0.1.11:8000/docs
# Health:   http://10.0.1.11:8000/health
```

**Python tests (36 assertions, no real nodes needed):**
```bash
cd backend
PYTHONPATH=. python -m pytest tests/ -v
# Expected: 36 passed
```

### 4. Start Monitoring Stack

```bash
cd monitoring
docker compose -f docker-compose.monitoring.yml up -d

# Prometheus: http://10.0.1.11:9090
# Grafana:    http://10.0.1.11:3001  (admin / cis-grafana)
```

**Install JMX Exporter on each Cassandra node:**
```bash
# Download jmx_prometheus_javaagent-0.20.0.jar to each node
# Add to /etc/cassandra/jvm.options:
-javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx_exporter/jmx_exporter.yml
sudo systemctl restart cassandra
```

### 5. Start the Dashboard (Member 4 — Frontend)

```bash
cd frontend
cp .env.example .env
# Edit .env: set VITE_API_URL and VITE_GRAFANA_URL

npm install
npm run dev
# Dashboard: http://localhost:5173
```

**Frontend tests (27 assertions):**
```bash
cd frontend
npm test
# Expected: 27 passed
```

**Production build:**
```bash
npm run build   # outputs to frontend/dist/
```

---

## Demo Walkthrough

### Live Demo Script (~10 minutes)

**Step 1 — Show unhardened state:**
```bash
# SSH into node 1
ssh cassandra@10.0.1.11
sudo bash /opt/cis/cis-tool.sh audit all
# Expected: multiple FAIL (auth disabled, no TLS, no audit logging)
```

**Step 2 — Dashboard before hardening:**
- Open `http://localhost:5173`
- Click **Run Audit** — shows red cards with low compliance %
- Click a node card → expand a FAIL check → show evidence

**Step 3 — Apply hardening live:**
```bash
# CLI approach (impressive for terminal demo)
sudo bash /opt/cis/cis-tool.sh harden all
```
Or use the dashboard:
- Click **Auto-Remediate** on a remediable check
- Watch the AuditProgress overlay in the bottom-right

**Step 4 — Show hardened state:**
```bash
sudo bash /opt/cis/cis-tool.sh audit all
# Expected: all PASS (green output)
```

**Step 5 — Dashboard after hardening:**
- Click **Run Audit** again
- All 3 node cards now show high compliance %
- Switch to **Monitoring** tab → Grafana with live metrics

**Step 6 — Show CI/CD pipeline:**
- Open GitHub → Actions → `CIS Cassandra CI`
- Point to the 4 jobs: lint-bash → test-backend → test-frontend → security-scan
- Show bandit SAST output on backend

---

## Project Structure

```
cis-cassandra/
├── scripts/
│   ├── cis-tool.sh              # Main dispatcher (audit|harden <section>)
│   ├── lib/
│   │   ├── common.sh            # Logging, JSON helpers, SSH exec
│   │   ├── audit_section1-5.sh  # 20 CIS audit checks
│   │   ├── harden_section1-5.sh # 20 CIS remediation functions
│   │   └── demo.sh              # Live demo helper script
│   ├── cluster/
│   │   ├── health_check.sh      # 3-node cluster health
│   │   └── rolling_restart.sh   # Safe rolling restart
│   └── tests/
│       └── test_audit.sh        # 31 bash unit tests
│
├── backend/
│   ├── main.py                  # FastAPI app, CORS, health endpoint
│   ├── models.py                # Pydantic v2 models (AuditReport, etc.)
│   ├── config.py                # pydantic-settings from .env
│   ├── services/
│   │   ├── ssh_runner.py        # Paramiko SSH client
│   │   └── audit_parser.py      # JSON → AuditReport, command builders
│   ├── routers/
│   │   ├── audit.py             # GET /api/audit/* + SSE stream
│   │   ├── harden.py            # POST /api/harden/*
│   │   └── cluster.py           # GET /api/cluster/status
│   └── tests/                   # 36 pytest tests (mocked SSH)
│
├── frontend/
│   ├── src/
│   │   ├── App.tsx              # Tab shell (Compliance / Monitoring)
│   │   ├── types.ts             # TypeScript interfaces
│   │   ├── api.ts               # Fetch wrapper
│   │   ├── hooks/
│   │   │   ├── useAudit.ts      # Cluster audit state machine
│   │   │   └── useAuditStream.ts # SSE streaming hook
│   │   ├── components/
│   │   │   ├── NodeScoreCard.tsx # Per-node compliance card
│   │   │   ├── CheckRow.tsx      # Expandable check row w/ evidence
│   │   │   └── AuditProgress.tsx # Fixed overlay during audit/stream
│   │   └── pages/
│   │       ├── CompliancePage.tsx # Main compliance view
│   │       └── MonitoringPage.tsx # Grafana iframe + quick links
│   └── src/tests/               # 27 Vitest tests
│
├── monitoring/
│   ├── docker-compose.monitoring.yml
│   ├── prometheus/
│   │   ├── prometheus.yml        # Scrape config (3 nodes + backend)
│   │   └── jmx_exporter.yml     # JMX → Prometheus rules
│   └── grafana/
│       └── provisioning/        # Auto-provisioned datasource + dashboard
│
├── .github/
│   └── workflows/
│       └── cis-audit.yml        # 4-job CI pipeline
│
└── task_summary/                # Team member assignments
```

---

## Environment Variables

### Backend (`backend/.env`)
```
NODE_IPS=10.0.1.11,10.0.1.12,10.0.1.13
CIS_SSH_KEY=~/.ssh/cis_key
CIS_SSH_USER=cassandra
```

### Frontend (`frontend/.env`)
```
VITE_API_URL=http://10.0.1.11:8000
VITE_GRAFANA_URL=http://10.0.1.11:3001
```

---

## CI/CD Pipeline

The GitHub Actions pipeline runs on every push and PR:

```
lint-bash ──────────────────────────────────┐
test-backend (pytest 36 tests) ─────────────┤──► security-scan
test-frontend (vitest 27 + tsc + build) ────┘    (bandit SAST)
```

Security gate: `bandit` scans the FastAPI backend for medium+ severity Python security issues.

---

## Team

| Member | Role | Key Deliverables |
|---|---|---|
| **Member 1** | Infrastructure & DevOps | 3-node VM cluster, Prometheus, Grafana, WireGuard VPN |
| **Member 2** | CIS Scripting & Hardening | 20 audit checks, 20 harden functions, `cis-tool.sh` |
| **Member 3** | Backend API | FastAPI, SSH orchestration, SSE streaming, 36 tests |
| **Member 4** | Frontend & CI/CD | React dashboard, 27 tests, GitHub Actions 4-job pipeline |

---

## References

- [CIS Apache Cassandra 4.0 Benchmark v1.3.0](https://www.cisecurity.org/benchmark/apache_cassandra)
- [Apache Cassandra 4.0 Documentation](https://cassandra.apache.org/doc/4.0/)
- [OWASP DevSecOps Guideline](https://owasp.org/www-project-devsecops-guideline/)
