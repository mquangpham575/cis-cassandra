# 🚀 Infrastructure Setup (Member 1)

This document summarizes the final state of the 3-node Cassandra cluster after handling Azure Student Subscription policy restrictions and capacity issues.

### 📍 Cluster Overview
| Attribute | Configuration |
| :--- | :--- |
| **Region** | **Southeast Asia (Singapore)** |
| **VM Size** | `Standard_B2ps_v2` (ARM64 — 2 vCPU / 4GB RAM) |
| **Architecture** | **ARM64 (aarch64)** |
| **Operating System** | Ubuntu 22.04 LTS (Jammy) |
| **Storage** | 30 GB Standard SSD / node |

### 🛠️ Provisioned Resources
| Node | Role | Private IP | Public IP | SSH Command |
| :--- | :--- | :--- | :--- | :--- |
| **node1** | Seed | `10.0.1.11` | `4.193.213.85` | `ssh -i ~/.ssh/cis_key cassandra@4.193.213.85` |
| **node2** | Node | `10.0.1.12` | `4.193.208.18` | `ssh -i ~/.ssh/cis_key cassandra@4.193.208.18` |
| **node3** | Node | `10.0.1.13` | `4.193.98.211` | `ssh -i ~/.ssh/cis_key cassandra@4.193.98.211` |

### 🔐 Access and Security
*   **SSH Access**: Restricted to current Member 1 IP (`14.187.93.155`). To update, modify `variables.tf` and run `terraform apply`.
*   **Authentication**: Key-based only (No passwords). Use the generated `cis_key` file.
*   **NSG Ports**:
    *   `22` (SSH) — Restricted to Member 1 IP.
    *   `7000-7001` (Internal Cluster) — Open within the VNet.
    *   `9042` (CQL Native Port) — Open within the VNet.

### ⚠️ Infrastructure Troubleshooting (Handled)
*   **SKU Availability**: Original `Standard_B2s` was out of capacity in Singapore. Switched to `B2ps_v2` (ARM64).
*   **Policy Restriction**: Student accounts are restricted from US/Hong Kong regions. Locked to `Southeast Asia`.
*   **ARM64 Compatibility**: Updated `vms.tf` with the correct `arm64` Ubuntu image and adjusted `cloud-init` for the `openjdk-arm64` path.

### 🏁 Team Hand-off & Connection Guide (Members 2 & 3)

Follow these steps to connect to the infrastructure configured by Member 1.

#### 1. Save and Secure the SSH Key
Save the `cis_key` file provided by Member 1 (usually in `~/.ssh/`).
On Windows, you **must** restrict file permissions or SSH will refuse to use it:
```powershell
# Run this in PowerShell where the cis_key is located:
icacls .\cis_key /inheritance:r
icacls .\cis_key /grant:r "$($env:USERNAME):(R)"
```

#### 2. Update the Firewall
The Azure Firewall (NSG) currently only allows Member 1's IP. To allow your own IP:
1.  Check your current IP on `ifconfig.me`.
2.  Ask Member 1 to add it to `variables.tf` in the `allowed_ssh_cidr` list.
3.  Member 1 runs `terraform apply`.

#### 3. Test the Connection
Try logging into Node 1 (Seed):
```bash
ssh -i cis_key cassandra@4.193.213.85
```

Once logged in, verify Cassandra is present:
```bash
cassandra -v
# (Optional) Start it manually to check status
sudo systemctl start cassandra
nodetool status
```

---
*Created by Infrastructure Assistant for DevSecOps Team Project.*
