# CIS Apache Cassandra 4.0 — DevSecOps Compliance Platform

> **NT542.Q22 DevSecOps — Group Project**  
> Implementation of CIS Apache Cassandra 4.0 Benchmark v1.3.0 across an automated 4-node Azure infrastructure.

---

## 📋 Executive Summary

This platform provides an automated solution to **audit** and **harden** a 4-node Apache Cassandra 4.0 cluster according to the **CIS Benchmark v1.3.0** standards. It integrates infrastructure-as-code, real-time security orchestration, and modern observability into a unified DevSecOps workflow.

### System Components

| Layer | Technology | Purpose |
|---|---|---|
| **Cloud Infrastructure** | 4 × Azure Ubuntu 22.04 (x86_64) | 1 Master + 3 DB Nodes (`Standard_B2als_v2`) |
| **Security Engineering** | Bash (`scripts/`) | Procedural CIS audit and automated remediation |
| **Orchestration API** | FastAPI (Python 3.12) | SSH-based dispatching, SSE reports, and status management |
| **Management Portal** | React 18 + Vite | Centralized compliance dashboard |
| **CI/CD Pipeline** | GitHub Actions | Automated security gates (Static Analysis, Linting, Testing) |

---

## 🏗️ System Architecture

The platform operates on a decentralized scanning model where the **Orchestration API** dispatches non-intrusive audit and hardening commands to the cluster nodes over encrypted SSH channels.

```mermaid
graph TD
    User([Security Engineer]) -->|HTTPS| Frontend[React Dashboard]
    Frontend -->|API/SSE| Backend[FastAPI Orchestrator]
    
    subgraph "Azure Secure VNet (10.0.1.0/24)"
        Backend -->|SSH| Master[Master: Jump Host]
        Master -->|SSH Internal| DB1[DB Node 1: Seed]
        Master -->|SSH Internal| DB2[DB Node 2]
        Master -->|SSH Internal| DB3[DB Node 3]
        
        DB1 --- DB2
        DB2 --- DB3
    end
```

---

## 🚀 Deployment & Operations

### 1. Infrastructure Provisioning (Member 1)

The infrastructure is fully automated via **Terraform** and **Cloud-Init**. All nodes are provisioned with the baseline security and database components pre-installed.

```bash
# Verify cluster baseline (Automated via Cloud-Init)
nodetool status
java -version
```

### 1.1 Operational Efficiency & Cost Management

To optimize **Azure Student Credit** usage, the system includes an operational power management utility. This allows for deallocating compute resources when idle while maintaining disk integrity.

**Power Management (Windows PowerShell):**
```powershell
# Check current power state of cluster nodes
.\scripts\cluster-power.ps1 status

# Provision/Start all nodes (Warm-up time: 2-3 mins)
.\scripts\cluster-power.ps1 start

# Deallocate all nodes (Stops compute billing)
.\scripts\cluster-power.ps1 stop
```

---

### 2. CIS Security Hardening (Member 2)

The system supports granular or full-cluster security enforcement according to CIS recommendations.

```bash
# Execute full security audit
sudo bash scripts/cis-tool.sh audit all

# Apply automated remediation (Hardening)
sudo bash scripts/cis-tool.sh harden all

# Section-specific auditing
sudo bash scripts/cis-tool.sh audit 2  # Authentication focus
```

---

### 3. Orchestration & Monitoring (Members 3 & 4)

#### Backend Dispatcher
```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000
# Documentation: http://4.194.10.192:8000/docs
```

#### SSH Jump Access
To access the database nodes, use the Master node as a jump host:
1. **Connect to Master**: `ssh cassandra@<PUBLIC_IP>`
2. **Jump to DB**: `ssh 10.0.1.11` (Key is pre-deployed on Master)

---

## 🛡️ DevSecOps Pipeline

The GitHub Actions workflow enforces a **Security-First** release policy on every commit to `main`:

1.  **Static Analysis**: `bandit` scans for Python-level security vulnerabilities.
2.  **Linting**: Ensures codebase consistency for Bash, Python, and TypeScript.
3.  **Automated Testing**:
    - **Backend**: 36 test cases (Pytest).
    - **Frontend**: 27 test cases (Vitest).
    - **Bash**: 31 assertions (BATS-compliant).
4.  **Security Gate**: The pipeline **blocks merges** if any **CRITICAL** CIS violations are detected in the audit baseline.

---

## 👥 Team Assignments

| Role | Primary Responsibilities |
|---|---|
| **Infrastructure & DevOps** | Azure VNet/Subnet design, OIDC authentication, Security Hardening |
| **Security Engineering** | CIS Baseline logic, Hardening scripts, Bash unit tests |
| **Backend Integration** | API Orchestration, SSH Parallelization, SSE real-time streaming |
| **Frontend & QA** | Management UI/UX, Vitest suites, CI/CD Security Gates |

---

## 📚 References

- [CIS Apache Cassandra 4.0 Benchmark v1.3.0](https://www.cisecurity.org/benchmark/apache_cassandra)
- [NIST SP 800-53 Security Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [Azure Security Best Practices](https://learn.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
