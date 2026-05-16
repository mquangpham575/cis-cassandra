# CIS Apache Cassandra 4.0 — DevSecOps Compliance Platform

> **NT542.Q22 DevSecOps — Final Project**  
> Tự động hóa đánh giá an ninh (Audit) và khắc phục lỗ hổng (Hardening) cho cụm Apache Cassandra 4.0 theo tiêu chuẩn **CIS Benchmark v1.3.0**.

---

## 🚀 Chạy Demo Nhanh (Không cần cài đặt)
Chúng tôi cung cấp 3 kịch bản Demo để trình diễn tính năng ngay trên môi trường Linux/MacOS/WSL:

| Scenario | Lệnh thực thi | Mô tả |
| :--- | :--- | :--- |
| **Demo 1: Audit** | `bash demo/demo_audit.sh` | Quét cấu hình lỗi và chỉ ra các lỗ hổng bảo mật. |
| **Demo 2: Harden** | `bash demo/demo_harden.sh` | Tự động sửa lỗi (Remediate) từ FAIL sang PASS. |
| **Demo 3: Report** | `bash demo/demo_report.sh` | Quét toàn bộ cụm giả lập và xuất báo cáo JSON/CSV. |

---

## 🏗️ Cấu hình Hệ thống Thực tế (Azure)
Dự án được triển khai trên Azure với mô hình điều phối tập trung:
- **Master Node**: Điều phối và chạy Dashboard.
- **3 DB Nodes**: Cụm Cassandra 4.0 thực tế chạy trên CentOS Stream.

### Lệnh chạy trực tiếp trên Cluster:
```bash
# Thực hiện Audit toàn cụm
sudo bash scripts/cis-tool.sh cluster audit

# Khắc phục lỗi tự động
sudo bash scripts/cis-tool.sh cluster harden
```

---

## 🛡️ DevSecOps CI/CD Pipeline
Hệ thống tích hợp quy trình kiểm soát an ninh tự động qua GitHub Actions:

1.  **Linting**: Đảm bảo tất cả Script Bash và mã nguồn Frontend chuẩn hóa.
2.  **Testing**: Chạy Unit Test cho cả Backend (Python) và Frontend (Vite/React).
3.  **Security Scan**: Quét lỗ hổng mã nguồn bằng `Bandit`.
4.  **Security Gate**: **Tự động chặn Merge** nếu phát hiện vi phạm CIS mức độ **CRITICAL**.
5.  **Infrastructure Audit**: Tự động kiểm tra trạng thái sức khỏe của Cluster trên Azure.

---

## 📊 Phạm vi tuân thủ (CIS v1.3.0)
| Mục tiêu | Trạng thái | Tự động hóa |
| :--- | :--- | :--- |
| **1. Installation** | ✅ PASS | 100% |
| **2. Auth/Authz** | ✅ PASS | 100% |
| **3. Access Control** | ✅ PASS | 80% (Cần Review thủ công) |
| **4. Logging** | ✅ PASS | 100% |
| **5. Encryption** | ❌ FAIL | Đang chờ triển khai PKI |

---
**Giảng viên hướng dẫn**: [Tên giảng viên]  
**Sinh viên thực hiện**: [Tên sinh viên]
