#!/usr/bin/env bash
# Demo Flow 2: Tối ưu Kernel (Swappiness)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
export NO_JSON=1

# Load common properties if available
if [[ -f "$DIR/scripts/lib/common.sh" ]]; then source "$DIR/scripts/lib/common.sh"; fi

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"; echo -e "┃ $* "; echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }

log_header "FLOW 2: TỐI ƯU HÓA KERNEL (VM.SWAPPINESS) TRÊN NODE 2 (10.0.1.12)"

# 1. LÀM SAI (BREAK)
log_info "BƯỚC 1: Đưa cấu hình về mặc định (vm.swappiness=60) trên Node 2..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.12" "sudo sysctl -w vm.swappiness=60" > /dev/null
echo -e "   -> Giá trị hiện tại trên Node 2: $(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.12" 'sysctl vm.swappiness')"

# 2. KIỂM TRA (AUDIT)
log_info "BƯỚC 2: Chạy Audit trên Node 2 để phát hiện lỗi hiệu năng..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.12" "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*6" -A 5

# 3. VÁ LỖI (HARDEN)
log_info "BƯỚC 3: Tối ưu hóa hệ thống tự động trên Node 2..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.12" "sudo bash ~/cis-tool/cis-tool.sh harden --section os" > /dev/null
log_ok "Lệnh Hardening đã được thực thi trên Node 2."

# 4. XÁC NHẬN (VERIFY)
log_info "BƯỚC 4: Kiểm tra lại thông số Kernel trên Node 2..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.12" "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*6" -A 5

# 5. XUẤT BÁO CÁO (OUTPUT)
log_info "BƯỚC 5: Khởi tạo báo cáo cho riêng hạng mục này..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.12" "sudo NO_JSON= bash ~/cis-tool/cis-tool.sh audit --section os" | grep "^{" > /tmp/cis_results.json
python3 "$DIR/scripts/export_excel.py"
log_ok "Báo cáo Excel đã sẵn sàng: CIS_Cassandra_Compliance_Report.xlsx"

log_header "KẾT THÚC FLOW 2: NODE 2 ĐÃ TỐI ƯU & CÓ BÁO CÁO"
