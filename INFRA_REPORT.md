# BÁOCÁO CHI TIẾT: PHẦN INFRASTRUCTURE CIS-CASSANDRA

**Dự án:** NT542.Q22 — DevSecOps Platform  
**Thành viên:** Member 1 (Infrastructure)  
**Ngày:** Tháng 5, 2026  
**Môi trường:** Microsoft Azure Southeast Asia

---

## III. TRIỂN KHAI

### 3.1 MÔ HÌNH

#### 3.1.1 Lớp Hạ Tầng (Infrastructure Layer - Target Environment)

**Định nghĩa vấn đề:**

Trong một dự án DevSecOps, hạ tầng không chỉ là máy chủ mà là **nền tảng pháp lý** để có thể:

- Triển khai, quản lý, và kiểm thử cluster Cassandra 4.0 an toàn
- Áp dụng quy chuẩn bảo mật CIS Benchmark v1.3.0 một cách tự động
- Cho phép đội khác (Member 2, 3, 4) truy cập và làm việc mà không cần lo xmất mất bảo mật

**Mô hình kiến trúc tổng thể:**

```
┌────────────────────────────────────────────────────────────────┐
│               Microsoft Azure Southeast Asia (Singapore)       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │   Virtual Network: 10.0.0.0/16                         │    │
│  │   ┌──────────────────────────────────────────────────┐ │    │
│  │   │   Subnet: 10.0.1.0/24 (Cassandra Cluster)       │ │    │
│  │   │                                                  │ │    │
│  │   │   ┌─────────────┐                               │ │    │
│  │   │   │   MASTER    │ IP: 10.0.1.10                │ │    │
│  │   │   │ B2ats_v2    │ Public IP: 4.194.10.192 ◄────┼─┼─┬──┤
│  │   │   │ 1vCPU/1GB   │ (Jump Host)                 │ │ │  │
│  │   │   │             │────┐                          │ │ │  │
│  │   │   └─────────────┘    │ SSH Relay via PrivKey   │ │ │  │
│  │   │        │              │                          │ │ │  │
│  │   │   ┌────┴────────┬─────┴────┬─────────────────┐  │ │ │  │
│  │   │   │             │          │                  │  │ │ │  │
│  │   │  ┌─▼──┐    ┌─▼──┐    ┌─▼──┐                 │  │ │ │  │
│  │   │  │DB1 │    │DB2 │    │DB3 │                 │  │ │ │  │
│  │   │  │Seed│    │Data│    │Data│                 │  │ │ │  │
│  │   │  │    │    │    │    │    │                 │  │ │ │  │
│  │   │  │B2als│   │B2als│  │B2als│                │  │ │ │  │
│  │   │  │2vCPU│   │2vCPU│  │2vCPU│                │  │ │ │  │
│  │   │  │4GB  │   │4GB  │  │4GB  │                │  │ │ │  │
│  │   │  │     │   │     │  │     │                │  │ │ │  │
│  │   │  │10.0.│   │10.0.│  │10.0.│                │  │ │ │  │
│  │   │  │1.11 │   │1.12 │  │1.13 │                │  │ │ │  │
│  │   │  └──┬──┘   └──┬──┘  └──┬──┘                 │  │ │ │  │
│  │   │     │        │        │                     │  │ │ │  │
│  │   │     └────────┼────────┘                     │  │ │ │  │
│  │   │              │                              │  │ │ │  │
│  │   │        Inter-node Cluster (Port 7000)      │  │ │ │  │
│  │   └──────────────────────────────────────────┘  │ │ │  │
│  │                                                   │ │ │  │
│  │   Network Security Group (NSG) — Firewall:      │ │ │  │
│  │   • Port 22   (SSH): Only from whitelisted IPs ◄┼─┼─┘  │
│  │   • Port 7000 (Inter-node): Internal only        │ │     │
│  │   • Port 9042 (Client):     Blocked by default   │ │     │
│  │                                                   │ │     │
│  └────────────────────────────────────────────────────┘ │     │
│                                                           │     │
└───────────────────────────────────────────────────────────┘     │
                                                                   │
        Azure Resource Group: cis-cassandra-rg                    │
```

**Thành phần chính:**

| Thành phần      | Mô tả                     | Vai trò                   | Lý do chọn                                                                                               |
| :-------------- | :------------------------ | :------------------------ | :------------------------------------------------------------------------------------------------------- | -------------- |
| **Master Node** | B2ats_v2 (1vCPU, 1GB)     | Jump Host + Orchestration | • Điểm truy cập duy nhất từ internet.<br>• SSH relay đến các DB nodes.<br>• Chạy FastAPI/Dashboard backend. |
| **DB1 (Seed)**  | B2als_v2 (2vCPU, 4GB)     | Cassandra Seed Node       | • Điểm khởi động cluster.<br>• Lưu trữ gossip protocol metadata.<br>• Quota restriction: đủ tài nguyên.     |
| **DB2, DB3**    | B2als_v2 (2vCPU, 4GB)     | Data Nodes                | • Nút lưu trữ dữ liệu.<br>• Sao chép replica.                                                              |
| **VNet/Subnet** | 10.0.0.0/16 / 10.0.1.0/24 | Network Isolation         | • Đủ IP cho mở rộng.<br>• Private subnet cho DB nodes.<br>• NSG filtering.                                  |

**Vấn đề gặp phải và giải pháp:**

Khi triển khai lần đầu, chúng tôi gặp ba rủi ro lớn:

1. **Quota Limitation (Giới hạn tài nguyên):**
   - Azure Student Subscription: Tối đa 6 cores.
   - 4 nodes × 2 cores = 8 cores → **VƯỢT QUOTA**.
   - **Giải pháp:** Yêu cầu tăng quota lên 8 cores (được chấp thuận). Downgrade Master từ B2als → B2ats (1 core) để tiết kiệm.
   - **Kết quả:** Tổng 7 cores (1 Master + 3×2 Data) = **Nằm trong quota mới**.

2. **Capacity Crisis (Thiếu tài nguyên máy chủ):**
   - VM size B1s (1 core) → Đã hết hàng ở Southeast Asia.
   - VM size F1s (1 core) → Cũng hết hàng.
   - **Giải pháp:** Chuyển sang B2ats_v2 (1 core) có sẵn.
   - **Ảnh hưởng:** Thay đổi kiến trúc từ 4 nodes thành 1 Master + 3 Data nodes.

3. **Architecture Mismatch (Kiến trúc không phù hợp):**
   - Ban đầu muốn dùng ARM64 (rẻ hơn).
   - Azure Southeast Asia chỉ có x86_64 stock sẵn.
   - **Giải pháp:** Dùng x86_64 (tương thích tốt hơn với Cassandra).
   - **Nhân rộng:** Chọn AMD x86_64 để đảm bảo tuân thủ CIS (CIS chủ yếu kiểm tra x86_64).

#### 3.1.2 Các Phương Pháp Thực Hiện Manual (Manual Compliance Methods)

Theo chuẩn CIS Cassandra Benchmark v1.3.0, các bước **Manual** là những kiểm tra yêu cầu sự can thiệp và đánh giá trực tiếp của con người. Chúng thường liên quan đến các chính sách tổ chức hoặc các cấu hình không thể xác minh bằng script một cách tin cậy 100%.

**Định nghĩa trong dự án:**

- **Audit Manual:** Sử dụng quyền SSH truy cập trực tiếp vào từng node để chạy các lệnh kiểm tra (Audit) được liệt kê trong benchmark.
- **Remediation Manual:** Chỉnh sửa cấu hình thủ công qua `vi` hoặc `nano` khi phát hiện lỗi không tuân thủ.

**Danh sách đầy đủ các hạng mục Manual (Dựa trên cis_cassandra.txt):**

| ID  | Tiêu đề (CIS Recommendation) | Phương pháp thực hiện Manual |
| :--- | :--- | :--- |
| **1.1** | Ensure a separate user and group exist | Kiểm tra file `/etc/passwd` và `/etc/group` để xác nhận user `cassandra` tồn tại. |
| **1.6** | Ensure clocks are synchronized | Chạy `timedatectl status` để xác nhận NTP đang hoạt động chính xác trên toàn cluster. |
| **3.3** | Ensure no unnecessary roles/privileges | Truy cập `cqlsh`, chạy `LIST ROLES` và đối chiếu với danh sách nhân sự thực tế. |
| **3.5** | Listen only on authorized interfaces | Kiểm tra `rpc_address` và `listen_address` trong `cassandra.yaml` so với sơ đồ mạng. |
| **3.6** | Data Center Authorizations activated | Xác minh cấu hình `authorizer: CassandraAuthorizer` và phân vùng DC. |
| **3.7** | Review User-Defined Roles | Kiểm tra thủ công các quyền `GRANT` đặc thù được cấp cho người dùng cuối. |
| **3.8** | Review Superuser/Admin Roles | Xác minh danh sách người dùng có quyền `SUPERUSER` để hạn chế tối đa rủi ro. |
| **4.2** | Ensure that auditing is enabled | Kiểm tra phần `audit_logging_options` trong `cassandra.yaml` và xác nhận log file được tạo ra. |

**Lý do chọn Manual cho các bước này:**
- Đảm bảo tính chính xác tuyệt đối cho các yếu tố định danh (Identity).
- Các bước 3.3, 3.7, 3.8 yêu cầu sự phán đoán của con người về tính "cần thiết" của một vai trò.
- Tránh rủi ro automation làm gián đoạn dịch vụ khi cấu hình file yaml nhạy cảm.

#### 3.1.3 Các Phương Pháp Thực Hiện Automation (Automated Compliance Methods)

Automation là trọng tâm của DevSecOps. Trong dự án này, chúng tôi tự động hóa việc kiểm tra (Audit) và khắc phục (Remediation) cho phần lớn các đề xuất CIS có thể định nghĩa bằng logic code.

**Công cụ sử dụng:**

- **`cis-tool.sh`**: Script Bash đóng gói toàn bộ logic Audit của CIS Benchmark.
- **Python Backend (FastAPI)**: Điều phối việc thực thi script trên tất cả các node qua SSH và thu thập kết quả JSON.
- **Terraform/Cloud-init**: Tự động cấu hình các thiết lập bảo mật ngay từ khi khởi tạo (Security by Design).

**Danh sách đầy đủ các hạng mục Automation (Dựa trên cis_cassandra.txt):**

| ID  | Tiêu đề (CIS Recommendation) | Phương pháp thực hiện Automation |
| :--- | :--- | :--- |
| **1.2 - 1.4** | Version Checks (Java, Python, C*) | `cis-tool.sh` tự động so sánh version hiện tại với whitelist được định nghĩa trước. |
| **1.5** | Run as non-root user | Script kiểm tra owner của tiến trình cassandra qua lệnh `ps`. |
| **2.1 - 2.2** | Auth & Authz Enabled | Tự động quét `cassandra.yaml` để tìm `PasswordAuthenticator` và `CassandraAuthorizer`. |
| **3.1** | Separate cassandra/superuser roles | Script kiểm tra danh sách roles và cảnh báo nếu superuser dùng chung account mặc định. |
| **3.2** | Default password change | Tự động thử đăng nhập với user `cassandra/cassandra` để xác nhận đã đổi mật khẩu. |
| **3.4** | Non-privileged service account | Kiểm tra quyền hạn của user chạy service để đảm bảo không có đặc quyền sudo/root. |
| **4.1** | Ensure logging is enabled | Tự động kiểm tra cấu hình `logback.xml` và log level. |
| **5.1 - 5.2** | Encryption settings | Tự động quét file `cassandra.yaml` để tìm các flag `internode_encryption` và `client_encryption`. |

**Lợi ích của Automation:**
- **Tốc độ:** Kiểm tra toàn bộ cluster (3 nodes) chỉ trong chưa đầy 5 giây.
- **Độ tin cậy:** Tránh sai sót do yếu tố mệt mỏi hoặc nhầm lẫn của con người.
- **Khả năng báo cáo:** Dữ liệu trả về dạng JSON giúp tích hợp dễ dàng vào Dashboard/Web UI và CI/CD pipeline.

---

### 3.2 TRIỂN KHAI CƠ SỞ HẠ TẦNG TRÊN MICROSOFT AZURE

#### 3.2.1 BƯỚC 0: THIẾT LẬP BIẾN MÔI TRƯỜNG

**Tại sao bước này cần thiết?**

Terraform cần biết:

- Tên project (sẽ gắn vào tất cả resources).
- Vị trí (region) để tối thiểu latency.
- Loại VM để control chi phí vs performance.
- SSH public key để bảo mật VM.
- IP ranges được phép SSH (firewall whitelist).

**Cách thực hiện:**

**Bước 0a: Đăng nhập Azure CLI**

```bash
# Kiểm tra account hiện tại
az account show

# Output:
# {
#   "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "name": "your-subscription-name",
#   "state": "Enabled",
#   "isDefault": true,
#   "user": {
#     "name": "user@example.com",
#     "type": "user"
#   }
# }
```

Nếu chưa login:

```bash
az login
# Sẽ mở browser để xác thực
```

**Bước 0b: Tạo SSH Key (nếu chưa có)**

```bash
# Tạo keypair
cd ssh/
ssh-keygen -t rsa -b 4096 -N "" -f cis_key -C "cassandra@cis-cassandra"

# Kết quả:
# cis_key      (private key, 400 permission)
# cis_key.pub  (public key, 644 permission)

# Không được share private key trên Git!
# Đã có .gitignore: *.key *.pem
```

**Bước 0c: Tạo Terraform Variables File**

```bash
cd terraform/
cat > terraform.tfvars <<'EOF'
project_name       = "cis-cassandra"
resource_group_name = "cis-cassandra-rg"
location            = "Southeast Asia"
vm_size             = "Standard_B2als_v2"      # Data nodes: 2vCPU, 4GB
master_vm_size      = "Standard_B2ats_v2"      # Master: 1vCPU, 1GB
ssh_public_key_path = "../ssh/cis_key.pub"

# CRITICAL: Thay bằng IPs công cộng của team members
# Format: CIDR blocks (e.g., 203.0.113.0/32 for single IP)
allowed_ssh_ips = [
  "203.0.113.10/32",    # Student 1 public IP
  "203.0.113.11/32",    # Student 2 public IP
  "203.0.113.12/32",    # Student 3 public IP
  "203.0.113.13/32",    # Student 4 public IP
]
EOF
```

**Lý do từng biến:**

| Biến              | Giá trị             | Lý do                                                         |
| :---------------- | :------------------ | :------------------------------------------------------------ |
| `project_name`    | `cis-cassandra`     | Prefix cho tất cả resources: `-vnet`, `-subnet`, `-nsg`, VMs. |
| `location`        | `Southeast Asia`    | Region gần nhất để minimize latency + giá tốt.                |
| `vm_size`         | `Standard_B2als_v2` | **2vCPU / 4GB** — Burstable VM, đủ cho Cassandra dev/test.    |
| `master_vm_size`  | `Standard_B2ats_v2` | **1vCPU / 1GB** — Đủ cho jump host + FastAPI.                 |
| `allowed_ssh_ips` | `[IP/32, ...]`      | **Firewall whitelist** — Chỉ những IPs này mới SSH được.      |

**Kiểm tra:**

```bash
# Verify files exist
ls -la terraform/terraform.tfvars
ls -la ssh/cis_key.pub

# Verify format
cat terraform/terraform.tfvars | grep -E "^[a-z_]+ = "
```

---

#### 3.2.2 BƯỚC 1: TẠO AZURE RESOURCE GROUP

**Định nghĩa Resource Group:**

Resource Group là **logical container** trong Azure để:

- Tập hợp tất cả resources (VNet, VMs, NSG) thành một "project".
- Dễ dàng quản lý, monitor, xóa toàn bộ cùng lúc.
- Gắn tags, billing, access control.

**Cách thực hiện:**

```bash
# Tạo RG từ CLI (không dùng Terraform để nhanh)
az group create \
  --name cis-cassandra-rg \
  --location "Southeast Asia"

# Output:
# {
#   "id": "/subscriptions/.../resourceGroups/cis-cassandra-rg",
#   "location": "southeastasia",
#   "name": "cis-cassandra-rg",
#   "properties": {
#     "provisioningState": "Succeeded"
#   },
#   "tags": {}
# }
```

**Kiểm tra:**

```bash
az group show --name cis-cassandra-rg

# Hoặc xem trong Portal: https://portal.azure.com → Resource groups
```

---

#### 3.2.3 BƯỚC 2: KHỞI TẠO TERRAFORM BACKEND (TÙY CHỌN)

**Tại sao cần backend?**

Mặc định, Terraform lưu state file cục bộ (`terraform.tfstate`). Vấn đề:

- Nếu xóa file, mất track của resources → không thể `terraform destroy`.
- Nhiều người làm việc → xung đột state.
- Không có version control.

**Giải pháp:** Lưu state trên Azure Blob Storage (remote backend)

**Cách thực hiện:**

```bash
# Tạo storage account cho state
az storage account create \
  --resource-group cis-cassandra-rg \
  --name sttfstate$(date +%s | md5sum | head -c 8) \
  --sku Standard_LRS

# Tạo container
az storage container create \
  --name tfstate \
  --account-name sttfstate123456

# Lấy storage account key
az storage account keys list --account-name sttfstate123456 -o table
```

Sau đó, uncomment trong `main.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "cis-cassandra-rg"
    storage_account_name = "sttfstate123456"
    container_name       = "tfstate"
    key                  = "cis-cassandra/terraform.tfstate"
  }
}
```

**Lưu ý:** Bước này **TÙY CHỌN** — nếu muốn giữ state cục bộ, bỏ qua.

---

#### 3.2.4 BƯỚC 3: KHỞI TẠO TERRAFORM

**Định nghĩa `terraform init`:**

Lệnh này:

- Download Terraform provider (azurerm v3.0)
- Khởi tạo `.terraform/` directory
- Chuẩn bị state management
- **Chỉ chạy một lần per environment**

**Cách thực hiện:**

```bash
cd terraform/
terraform init

# Output:
# Initializing the backend...
# ...
# Terraform has been successfully configured!
#
# You may now begin working with Terraform. Try running "terraform plan"
# to see any of the actions Terraform will perform.
```

**Kiểm tra:**

```bash
ls -la .terraform/
# → providers/registry.terraform.io/hashicorp/azurerm/...
```

---

#### 3.2.5 BƯỚC 4: VALIDATE TERRAFORM CODE

**Tại sao validate?**

Trước khi apply, verify:

- Syntax đúng.
- Variables đầu vào hợp lệ.
- Không có reference errors.
- Sẵn sàng deploy.

**Cách thực hiện:**

```bash
# 1. Validate syntax
terraform validate

# Output:
# Success! The configuration is valid.

# 2. Format check (cosmetic)
terraform fmt -check .

# 3. Preview changes (KHÔNG thay đổi gì)
terraform plan

# Output (cuối file):
# Plan: 11 to add, 0 to change, 0 to destroy.
#
# Changes to Outputs:
#   + master_public_ip = "..."
#   + cassandra_nodes = {...}
```

---

#### 3.2.6 BƯỚC 5: TRIỂN KHAI HẠNG TẦM (DEPLOY INFRASTRUCTURE) - MẤT 10-15 PHÚT

**Định nghĩa `terraform apply`:**

Lệnh này **thực sự tạo** các resources trên Azure dựa trên plan đã review.

**Cách thực hiện:**

```bash
terraform apply

# Terraform sẽ hiển thị preview (giống terraform plan)
# Rồi hỏi:
# Do you want to perform these actions?
# Type: yes<Enter>

# Terraform bắt đầu tạo resources...
# azurerm_resource_group.main: Creating...
# azurerm_resource_group.main: Creation complete after 2s
# azurerm_virtual_network.main: Creating...
# ...
# (chờ 10-15 phút)
# ...
# Apply complete! Resources: 11 added, 0 changed, 0 destroyed.
#
# Outputs:
# master_public_ip = "4.194.10.192"
# cassandra_nodes = {
#   "db1" = "10.0.1.11"
#   "db2" = "10.0.1.12"
#   "db3" = "10.0.1.13"
#   "master" = "10.0.1.10"
# }
```

**Thời gian chi tiết:**

| Tài nguyên         | Thời gian         | Ghi chú                           |
| :----------------- | :---------------- | :-------------------------------- |
| Resource Group     | ~2 giây           | Instant.                          |
| VNet + Subnet      | ~3 giây           | Instant.                          |
| NSG                | ~5 giây           | Instant.                          |
| Public IP (Master) | ~10 giây          | Instant.                          |
| NICs × 4           | ~15 giây          | Instant.                          |
| NSG Rules × 5      | ~20 giây          | Instant.                          |
| VM (Master)        | ~1 phút           | Cloud-init runs in parallel.      |
| VM (DB1, DB2, DB3) | ~3-4 phút **MỖI** | Sequential (Cassandra bootstrap). |
| **Total**          | **10-15 phút**    | Tuỳ vào queue.                    |

**Giải thích cloud-init timing:**

Mỗi VM chạy cloud-init sau khi OS boot:

```bash
# Master node cloud-init:
packages:
  - apt-transport-https
  - curl
  - python3.10
  # ~30 giây

# DB nodes cloud-init (thêm Cassandra):
packages:
  - openjdk-11-jdk         # ~30 giây
  - cassandra              # ~2-3 phút (từ apt repo)
runcmd:
  - systemctl stop cassandra
  - rm -rf /var/lib/cassandra/*
  - configure seed_provider = ["10.0.1.11"]  # DB1 IP
  # ~1 phút setup
```

**Lưu ý quan trọng:**

Terraform chỉ kiểm tra VM có tạo được hay không, **KHÔNG kiểm tra** Cassandra đã sẵn sàng hay chưa. Cần verify thêm (bước sau).

**Kiểm tra output:**

```bash
# Xem lại outputs (không cần run lại)
terraform output

# Lưu IPs vào biến
MASTER_IP=$(terraform output -raw master_public_ip)
echo "SSH tới Master: ssh -i ssh/cis_key cassandra@$MASTER_IP"
```

---

#### 3.2.7 BƯỚC 6: KIỂM TRA TERRAFORM STATE

**Tại sao cần kiểm tra?**

State file lưu thông tin chi tiết về từng resource — dùng để:

- Detect changes (terraform plan sau này).
- Track dependencies.
- Troubleshoot issues.

**Cách thực hiện:**

```bash
# Xem tóm tắt resources
terraform state list

# Output:
# azurerm_linux_virtual_machine.node["db1"]
# azurerm_linux_virtual_machine.node["db2"]
# azurerm_linux_virtual_machine.node["db3"]
# azurerm_linux_virtual_machine.node["master"]
# azurerm_network_interface.node["db1"]
# azurerm_network_interface.node["db2"]
# azurerm_network_interface.node["db3"]
# azurerm_network_interface.node["master"]
# azurerm_network_interface_security_group_association.node["db1"]
# azurerm_network_interface_security_group_association.node["db2"]
# azurerm_network_interface_security_group_association.node["db3"]
# azurerm_network_interface_security_group_association.node["master"]
# azurerm_network_security_group.cassandra
# azurerm_public_ip.node["master"]
# azurerm_resource_group.main
# azurerm_subnet.cassandra
# azurerm_virtual_network.main

# Xem chi tiết một resource
terraform state show 'azurerm_linux_virtual_machine.node["master"]'

# Output:
# resource "azurerm_linux_virtual_machine" "node" {
#   id                         = "/subscriptions/.../master"
#   location                   = "southeastasia"
#   name                       = "cis-cassandra-master"
#   size                       = "Standard_B2ats_v2"
#   admin_username             = "cassandra"
#   os_disk {...}
#   source_image_reference {...}
#   ...
# }
```

**Backup state (dự phòng):**

```bash
cp terraform.tfstate terraform.tfstate.backup
# Không commit vào Git — dùng .gitignore
```

---

#### 3.2.8 BƯỚC 7: POST-DEPLOY SSH CONFIGURATION

**Tại sao cần SSH config?**

VMs vừa được tạo, nhưng:

- Cassandra chưa sẵn sàng (cloud-init còn chạy).
- SSH key chưa được copy tới Master.
- SSH config chưa setup.
- Cần verify connectivity.

**Cách thực hiện:**

**Bước 7a: Chờ cloud-init hoàn thành (5-10 phút)**

```bash
# Kiểm tra cloud-init status trên VMs
MASTER_IP="4.194.10.192"  # Lấy từ terraform output
ssh -i ssh/cis_key cassandra@$MASTER_IP "sudo cloud-init status"

# Output (chờ đến khi thấy):
# status: done
# time: Tue, 15 May 2026 10:45:23 +0000
# detail: N/A
```

**Bước 7b: Copy SSH private key tới Master**

```bash
# Từ local machine:
scp -i ssh/cis_key ssh/cis_key cassandra@$MASTER_IP:~/.ssh/

# Xác minh:
ssh -i ssh/cis_key cassandra@$MASTER_IP "ls -la ~/.ssh/cis_key"
# -rw------- 1 cassandra cassandra 1704 May 15 10:50 .ssh/cis_key
```

**Bước 7c: Setup SSH config trên Master**

```bash
# SSH vào Master
ssh -i ssh/cis_key cassandra@$MASTER_IP

# Tạo SSH config file
cat > ~/.ssh/config <<'EOF'
Host db1 10.0.1.11
  HostName 10.0.1.11
  User cassandra
  IdentityFile ~/.ssh/cis_key
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null

Host db2 10.0.1.12
  HostName 10.0.1.12
  User cassandra
  IdentityFile ~/.ssh/cis_key
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null

Host db3 10.0.1.13
  HostName 10.0.1.13
  User cassandra
  IdentityFile ~/.ssh/cis_key
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
EOF

# Fix permissions
chmod 600 ~/.ssh/config

# Verify
cat ~/.ssh/config | head -20
```

**Bước 7d: Kiểm tra SSH connectivity tới DB nodes**

```bash
# Từ Master, test SSH tới DB1
ssh db1 "whoami && hostname"

# Output:
# cassandra
# cis-cassandra-db1

# Test tất cả nodes
for node in db1 db2 db3; do
  echo "=== Testing $node ==="
  ssh $node "uname -a"
done
```

---

#### 3.2.9 BƯỚC 8: KIỂM TRA CASSANDRA CLUSTER

**Tại sao cần kiểm tra?**

Cloud-init tạo VMs nhưng Cassandra khởi động độc lập. Cần verify:

- Cassandra process chạy trên từng node.
- Cluster thây nhau (gossip hoạt động).
- Seed node (`db1`) hoạt động bình thường.
- Không có lỗi bootstrap.

**Cách thực hiện:**

**Bước 8a: Kiểm tra Cassandra process**

```bash
# Từ Master, SSH tới DB1
ssh db1

# Check Cassandra process
ps aux | grep cassandra | grep -v grep

# Output (expected):
# cassandra 12345  5.2  35.6 2234512 145280 ?  Sl  10:45   0:15
# /usr/lib/jvm/java-11-openjdk-amd64/bin/java ... org.apache.cassandra.service.CassandraDaemon

# Check logs
tail -30 /var/log/cassandra/system.log | grep -E "INFO|ERROR|Joining|STARTED"

# Expected log lines (nếu node vừa boot):
# INFO  [main] 2026-05-15 10:50:22,456 CassandraServer.java:185 - Cassandra version: 4.0.20
# INFO  [main] 2026-05-15 10:50:23,100 DatabaseDescriptor.java:312 - seed_provider: [DefaultSeedProvider{seeds=[10.0.1.11]}]
# INFO  [main] 2026-05-15 10:50:30,234 Gossiper.java:1340 - Joined ring as node 123e4567-e89b-12d3-a456-426614174000
# INFO  [main] 2026-05-15 10:50:35,567 StorageService.java:1234 - STARTED
```

**Bước 8b: Kiểm tra cluster status**

```bash
# Từ Master
ssh db1 "nodetool status"

# Output (expected):
# Datacenter: datacenter1
# ======================
# Status=Up/Down
# |/ State=Normal/Leaving/Joining/Moving
# --  Address      Load       Tokens  Owns (effective)  Host ID                               Rack
# UN  10.0.1.11   100.0 KB   256     100.0%            12345678-1234-1234-1234-123456789012  rack1
# UN  10.0.1.12   100.0 KB   256     100.0%            87654321-4321-4321-4321-210987654321  rack1
# UN  10.0.1.13   100.0 KB   256     100.0%            11223344-5566-7788-9900-aabbccddeeff  rack1
#
# Status = U (Up)
# State  = N (Normal)
# Load   = ~100 KB/node (mới vừa boot)
# Tokens = 256 (default)
# Owns   = 100% (vì replication_factor=3 và chỉ có 3 nodes)
```

**Bước 8c: Kiểm tra quorum đồng thuận**

```bash
# Từ Master
ssh db1 "nodetool info"

# Output:
# ID               : 12345678-1234-1234-1234-123456789012
# Gossip active    : true
# Thrift active    : true
# Native Transport active : true
# Load             : 100.0 KB
# Generation       : 123
# Uptime (seconds) : 45
# Heap Memory (MB) : 234.56 / 1024.00
# Off Heap Memory (MB) : 10.00
# Data Center      : datacenter1
# Rack             : rack1
# Exceptions       : 0
# Key Cache        : entries 5, size 100 B, capacity 10 MB, 100% hitRate, 0 recent writes (0 microsec mean)
# Row Cache        : entries 0, size 0 B, capacity 0 B, 0% hitRate, 0 recent writes (0 microsec mean)
# Counter Cache    : entries 0, size 0 B, capacity 2.5 MB, 0% hitRate, 0 recent writes (0 microsec mean)
# Chunk Cache      : entries 6, size 384 B, capacity 100 MB, 0% hitRate, 0 recent writes (0 microsec mean)
```

**Troubleshooting (nếu cluster không OK):**

| Triệu chứng               | Nguyên nhân              | Giải pháp                                                            |
| :------------------------ | :----------------------- | :------------------------------------------------------------------- |
| `nodetool status` timeout | Cassandra chưa khởi động | Chờ 2-3 phút, check logs.                                            |
| Status = `DN` (Down)      | Node crash               | `systemctl status cassandra`, check `/var/log/cassandra/system.log`. |
| `Connection refused`      | Cassandra port không mở  | Check NSG rules (port 7000, 9042).                                   |
| Gossip error              | Seed node IP sai         | Check `cassandra.yaml`: `seed_provider` == `["10.0.1.11"]`.          |

---

#### 3.2.10 BƯỚC 9: CLONE REPOSITORY VÀ SETUP CIS TOOL

**Tại sao bước này cần thiết?**

Bây giờ infrastructure OK, cần:

- Copy scripts audit/harden (cis-tool.sh) tới cluster.
- Copy configuration files.
- Chuẩn bị backend API (FastAPI) để orchestrate audits.

**Cách thực hiện:**

**Bước 9a: Clone repo trên Master**

```bash
# Từ Master
ssh -i ssh/cis_key cassandra@$MASTER_IP

# Clone repo
git clone https://github.com/mquangpham575/cis-cassandra.git cis-repo
cd cis-repo

# Verify structure
ls -la | head -20
# backend/
# frontend/
# scripts/
# terraform/
# INFRA_SETUP.md
# README.md
```

**Bước 9b: Deploy CIS tool tới `/opt/cis`**

```bash
# Tạo directory
sudo mkdir -p /opt/cis
sudo chown cassandra:cassandra /opt/cis

# Copy scripts
cp -r scripts/* /opt/cis/
cp cis-tool.sh /opt/cis/

# Fix permissions
chmod 755 /opt/cis/cis-tool.sh
chmod 755 /opt/cis/sections/*.sh

# Test tool
/opt/cis/cis-tool.sh --help

# Output (expected):
# Usage: cis-tool.sh <command> [target] [options]
#
# Commands:
#   audit   [all|1|2|3|4|5|section_id]
#   harden  [all|1|2|3|4|5|section_id]
#   report  [--format json|text|html]
#   demo    [reset|attack]
#   cluster [deploy|restart|status|health-check]
```

**Bước 9c: Setup Python backend (tuỳ chọn, nếu cần dashboard)**

```bash
# Từ Master
cd cis-repo/backend

# Install dependencies
pip install -r requirements.txt

# Tạo systemd service (để chạy liên tục)
sudo cat > /etc/systemd/system/cis-backend.service <<'EOF'
[Unit]
Description=CIS Cassandra FastAPI Backend
After=network.target

[Service]
Type=simple
User=cassandra
WorkingDirectory=/home/cassandra/cis-repo/backend
ExecStart=/usr/bin/python3.10 -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable & start
sudo systemctl enable cis-backend
sudo systemctl start cis-backend

# Verify
sudo systemctl status cis-backend
# ● cis-backend.service - CIS Cassandra FastAPI Backend
#    Loaded: loaded (/etc/systemd/system/cis-backend.service; enabled)
#    Active: active (running) since ...
```

---

#### 3.2.11 BƯỚC 10: CHẠY AUDIT TRÊN CLUSTER ĐẦY ĐỦ

**Tại sao bước này cần thiết?**

Audit là **đánh giá tình trạng** cluster so với CIS Benchmark. Cần chạy toàn bộ 20 checks để:

- Biết node nào chưa compliant.
- Chuẩn bị cho bước hardening.
- Lưu baseline report.

**Cách thực hiện:**

**Bước 10a: Chạy audit cục bộ trên Master**

```bash
# Từ Master
sudo /opt/cis/cis-tool.sh audit all

# Output (ví dụ):
# ═══════════════════════════════════════════════════════════════
#  CIS Cassandra 4.0 Benchmark v1.3.0 - Audit Report
# ═══════════════════════════════════════════════════════════════
#
# [PASS] 1.1 - Ensure a separate user and group exist for Cassandra
#   → User: cassandra (UID 124)
#   → Group: cassandra (GID 124)
#
# [PASS] 1.2 - Ensure the latest version of Java is installed
#   → Installed: openjdk-11-jdk (11.0.20)
#   → Latest: 11.0.20+8
#
# [FAIL] 2.1 - Ensure that authentication is enabled
#   → Current: authenticator: AllowAllAuthenticator
#   → Required: authenticator: PasswordAuthenticator
#   → Status: NOT COMPLIANT
#
# [PASS] 4.1 - Ensure that logging is enabled
#   → Log level: INFO (in logback.xml)
#   → BinAuditLogger: ENABLED
#
# ...
#
# Summary:
#   ✓ PASS:   12/20
#   ✗ FAIL:   5/20
#   ⚠ MANUAL: 3/20
#
# Compliance Score: 60%
```

**Bước 10b: Chạy audit trên tất cả nodes (từ Master)**

```bash
# Audit trên DB1
sudo /opt/cis/cis-tool.sh audit all --node 10.0.1.11

# Audit trên DB2
sudo /opt/cis/cis-tool.sh audit all --node 10.0.1.12

# Audit trên DB3
sudo /opt/cis/cis-tool.sh audit all --node 10.0.1.13

# Hoặc audit tất cả cùng lúc:
sudo /opt/cis/cis-tool.sh audit all --all-nodes

# Output (nếu dùng --all-nodes):
# {
#   "timestamp": "2026-05-15T10:55:00Z",
#   "nodes": {
#     "10.0.1.11": {
#       "status": "UP",
#       "compliance_score": 60,
#       "results": [{
#         "check_id": "1.1",
#         "title": "Ensure a separate user and group exist...",
#         "status": "PASS"
#       }, ...]
#     },
#     "10.0.1.12": { ... },
#     "10.0.1.13": { ... }
#   },
#   "overall_score": 60
# }
```

**Lưu audit report:**

```bash
# Export JSON
sudo /opt/cis/cis-tool.sh report --format json > audit_baseline_$(date +%Y%m%d).json

# Export CSV (dễ đọc)
sudo /opt/cis/cis-tool.sh report --format text > audit_baseline_$(date +%Y%m%d).txt

# Lưu vào git (tất cả team members thấy được)
git add audit_baseline_*.json audit_baseline_*.txt
git commit -m "docs: baseline audit report after infrastructure deployment"
git push origin feat/integrated-nguyen-updates
```

---

#### 3.2.12 BƯỚC 11: VERIFY NETWORK SECURITY

**Tại sao bước này cần thiết?**

Firewall (NSG) là lớp bảo vệ đầu tiên. Cần verify:

- SSH chỉ từ whitelisted IPs.
- Inter-node traffic được phép.
- Cassandra ports không bị expose ra internet.
- Logging enabled (để audit attacks).

**Cách thực hiện:**

**Bước 11a: Kiểm tra NSG rules**

```bash
# Từ local machine
RESOURCE_GROUP="cis-cassandra-rg"
NSG_NAME="cis-cassandra-nsg"

# Xem rules
az network nsg rule list \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  -o table

# Output (expected):
# Name                    Priority  Direction  Access  Protocol  SourceAddressPrefix  SourcePortRange  DestinationAddressPrefix  DestinationPortRange
# AllowSSH_Whitelisted    100       Inbound    Allow   Tcp       [203.0.113.10/32]    *                10.0.1.0/24               22
#                                   Inbound    Allow   Tcp       [203.0.113.11/32]    *                10.0.1.0/24               22
# AllowInterNode          200       Inbound    Allow   Tcp       10.0.1.0/24          *                10.0.1.0/24               7000
# AllowClientCQL          300       Inbound    Allow   Tcp       10.0.1.0/24          *                10.0.1.0/24               9042
# DenyAllInbound          4096      Inbound    Deny    *         *                    *                *                         *
```

**Bước 11b: Kiểm tra NSG Logs**

```bash
# NSG flow logs được lưu trong Azure Storage
# (Cần bật flow logs trong Network Watcher)

# Bật flow logs nếu chưa có:
LOCATION="southeastasia"

# Tạo storage account
az storage account create \
  --resource-group $RESOURCE_GROUP \
  --name stnsgflow$(date +%s | md5sum | head -c 8) \
  --sku Standard_LRS \
  --location $LOCATION

# Bật NSG flow logs
az network watcher flow-log create \
  --resource-group $RESOURCE_GROUP \
  --enabled true \
  --nsg $NSG_NAME \
  --storage-account stnsgflow123456

# Verify logs
az network watcher flow-log show \
  --resource-group $RESOURCE_GROUP \
  --nsg $NSG_NAME \
  -o json | jq '.enabled'
# → true
```

**Bước 11c: Kiểm tra SSH whitelist**

```bash
# Test 1: SSH từ whitelisted IP (phải thành công)
ssh -i ssh/cis_key cassandra@$MASTER_IP "echo 'Access OK'"
# Output: Access OK

# Test 2: SSH từ non-whitelisted IP (phải timeout/denied)
# (Cần team member khác test hoặc VPN khác)
# Expected: Connection timeout sau 15 giây

# Test 3: Kiểm tra SSH port nghe
ssh -i ssh/cis_key cassandra@$MASTER_IP "netstat -tlnp | grep :22"
# Output: tcp  0  0 0.0.0.0:22  0.0.0.0:*  LISTEN  ...
```

**Bước 11d: Kiểm tra Cassandra port (phải blocked)**

```bash
# Từ local machine, test CQL port (phải timeout)
timeout 3 nc -zv $MASTER_IP 9042 2>&1 || echo "GOOD: Port 9042 blocked from outside"
# Output: GOOD: Port 9042 blocked from outside

# Từ Master, test CQL port (phải open)
ssh -i ssh/cis_key cassandra@$MASTER_IP "nc -zv 10.0.1.11 9042"
# Output: Connection to 10.0.1.11 9042 port [tcp/cql] succeeded!
```

---

## TÓМLƯỢC

| Bước      | Tiêu đề                   | Tài nguyên chính          | Thời gian      |
| :-------- | :------------------------ | :------------------------ | :------------- |
| 0         | Thiết lập biến môi trường | SSH key, terraform.tfvars | ~8 phút.       |
| 1         | Tạo Resource Group        | Azure RG                  | ~1 phút.       |
| 2         | Khởi tạo Terraform        | `.terraform/`             | ~1 phút.       |
| 3         | Validate Terraform        | Syntax checks             | ~1 phút.       |
| 4         | **Deploy infrastructure** | VNet, VMs, NSG            | **10-15 phút.** |
| 5         | Kiểm tra state            | terraform.tfstate         | ~1 phút.       |
| 6         | SSH post-config           | Master node setup         | ~5 phút.       |
| 7         | Verify Cassandra          | nodetool status           | ~5 phút.       |
| 8         | Clone repo & setup        | /opt/cis/, backend        | ~5 phút.       |
| 9         | Audit cluster             | Baseline report           | ~10 phút.      |
| 10        | Verify security           | NSG rules, flow logs      | ~5 phút.       |
| **TOTAL** |                           |                           | **~59 phút.**  |

**Chi phí Azure (ước tính hàng tháng):**

- 4 VMs × $15/tháng (B2 series) = $60.
- Storage (30GB × 3) × $0.0124/GB = ~$1.
- Network egress: ~$0 (internal).
- **TOTAL: ~$61/tháng** (rẻ cho dev/test).

---

**End of Infrastructure Report**  
_Member 1 — Infrastructure Setup and Deployment_  
_Date: May 15, 2026_
