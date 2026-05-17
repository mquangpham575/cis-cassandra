#!/usr/bin/env bash
# Demo Flow 3: Bảo mật mạng (Disable IPv6)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
export NO_JSON=1

# Load common properties if available
if [[ -f "$DIR/scripts/lib/common.sh" ]]; then source "$DIR/scripts/lib/common.sh"; fi

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"; echo -e "┃ $* "; echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }

log_header "FLOW 3: BẢO MẬT MẠNG (DISABLE IPV6) TRÊN NODE 3 (10.0.1.13)"

# 1. LÀM SAI (BREAK)
log_info "BƯỚC 1: Bật IPv6 (Không khuyến nghị cho Cassandra) trên Node 3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0" > /dev/null
echo -e "   -> Trạng thái hiện tại trên Node 3: disable_ipv6 = $(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" 'sysctl -n net.ipv6.conf.all.disable_ipv6')"

# 2. KIỂM TRA (AUDIT)
log_info "BƯỚC 2: Phát hiện cấu hình mạng không an toàn trên Node 3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*8" -A 5

# 3. VÁ LỖI (HARDEN)
log_info "BƯỚC 3: Vô hiệu hóa IPv6 tự động trên Node 3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo bash ~/cis-tool/cis-tool.sh harden --section os" > /dev/null
log_ok "Lệnh Hardening đã được thực thi trên Node 3."

# 4. XÁC NHẬN (VERIFY)
log_info "BƯỚC 4: Xác minh trạng thái mạng trên Node 3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*8" -A 5

# 5. XUẤT BÁO CÁO (OUTPUT)
log_info "BƯỚC 5: Khởi tạo báo cáo cho riêng hạng mục này..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo NO_JSON= bash ~/cis-tool/cis-tool.sh audit --section os" | grep "^{" > /tmp/cis_results.json
python3 "$DIR/scripts/export_excel.py"
log_ok "Báo cáo Excel đã sẵn sàng: CIS_Cassandra_Compliance_Report.xlsx"

log_header "KẾT THÚC FLOW 3: NODE 3 ĐÃ AN TOÀN & CÓ BÁO CÁO"
