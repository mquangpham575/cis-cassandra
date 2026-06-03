#!/usr/bin/env bash
# Demo Flow 3: Bảo mật Nhật ký (Audit Logging)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
export NO_JSON=1

# Load common properties if available
if [[ -f "$DIR/scripts/lib/common.sh" ]]; then source "$DIR/scripts/lib/common.sh"; fi

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"; echo -e "┃ $* "; echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }

log_header "FLOW 3: BẢO MẬT NHẬT KÝ (AUDIT LOGGING) TRÊN NODE 3 (10.0.1.13)"

# 1. LÀM SAI (BREAK)
log_info "BƯỚC 1: Cố tình cấu hình SAI (Tắt Audit Logging) trên Node 3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo awk '/^audit_logging_options:/ { in_block=1 } in_block && /^[^ #]/ && !/^audit_logging_options:/ { in_block=0 } in_block && /enabled: true/ { sub(/enabled: true/, \"enabled: false\") } { print }' /etc/cassandra/cassandra.yaml | sudo tee /etc/cassandra/cassandra.yaml.tmp > /dev/null && sudo mv /etc/cassandra/cassandra.yaml.tmp /etc/cassandra/cassandra.yaml && sudo systemctl restart cassandra"
echo -e "   -> Trạng thái hiện tại trên Node 3: $(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "grep -A 2 '^audit_logging_options:' /etc/cassandra/cassandra.yaml")"

# 2. KIỂM TRA (AUDIT)
log_info "BƯỚC 2: Chạy Audit trên Node 3 để phát hiện lỗi..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo bash ~/cis-tool/cis-tool.sh audit --section 4_audit" | grep -Ei "ID .*4\.2" -A 5

# 3. VÁ LỖI (HARDEN)
log_info "BƯỚC 3: Kích hoạt Hardening để tự động vá lỗi trên Node 3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo bash ~/cis-tool/cis-tool.sh harden --section 4_audit" > /dev/null
log_ok "Lệnh Hardening đã được thực thi trên Node 3."

# 4. XÁC NHẬN (VERIFY)
log_info "BƯỚC 4: Kiểm tra lại trạng thái cuối cùng trên Node 3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo bash ~/cis-tool/cis-tool.sh audit --section 4_audit" | grep -Ei "ID .*4\.2" -A 5

# 5. XUẤT BÁO CÁO (OUTPUT)
log_info "BƯỚC 5: Khởi tạo báo cáo cho riêng hạng mục này..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo NO_JSON= bash ~/cis-tool/cis-tool.sh audit --section 4_audit" | grep "^{" > /tmp/cis_results.json
python3 "$DIR/scripts/export_excel.py"
log_ok "Báo cáo Excel đã sẵn sàng: CIS_Cassandra_Compliance_Report.xlsx"

log_header "KẾT THÚC FLOW 3: NODE 3 ĐÃ AN TOÀN & CÓ BÁO CÁO"
