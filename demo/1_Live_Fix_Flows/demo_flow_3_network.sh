#!/usr/bin/env bash
# Demo Flow 3: Bảo mật mạng (Disable IPv6)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
export NO_JSON=1

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"; echo -e "┃ $* "; echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }

log_header "FLOW 3: BẢO MẬT MẠNG (DISABLE IPV6)"

# 1. LÀM SAI (BREAK)
log_info "BƯỚC 1: Bật IPv6 (Không khuyến nghị cho Cassandra)..."
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null
echo -e "   -> Trạng thái hiện tại: disable_ipv6 = $(sysctl -n net.ipv6.conf.all.disable_ipv6)"

# 2. KIỂM TRA (AUDIT)
log_info "BƯỚC 2: Phát hiện cấu hình mạng không an toàn..."
sudo -E bash "$DIR/cis-tool.sh" audit --section os | grep -Ei "ID .*8" -A 5

# 3. VÁ LỖI (HARDEN)
log_info "BƯỚC 3: Vô hiệu hóa IPv6 tự động..."
sudo -E bash "$DIR/cis-tool.sh" harden --section os > /dev/null
log_ok "Lệnh Hardening đã được thực thi."

# 4. XÁC NHẬN (VERIFY)
log_info "BƯỚC 4: Xác minh trạng thái mạng..."
sudo -E bash "$DIR/cis-tool.sh" audit --section os | grep -Ei "ID .*8" -A 5

# 5. XUẤT BÁO CÁO (OUTPUT)
log_info "BƯỚC 5: Khởi tạo báo cáo cho riêng hạng mục này..."
sudo bash "$DIR/cis-tool.sh" audit --section os > /dev/null
python3 "$DIR/scripts/export_excel.py"
log_ok "Báo cáo Excel đã sẵn sàng: CIS_Cassandra_Compliance_Report.xlsx"

log_header "KẾT THÚC FLOW 3: HỆ THỐNG ĐÃ AN TOÀN & CÓ BÁO CÁO"
