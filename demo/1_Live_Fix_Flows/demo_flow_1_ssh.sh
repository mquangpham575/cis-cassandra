#!/usr/bin/env bash
# Demo Flow 1: Bảo mật SSH (Root Login)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
export NO_JSON=1

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"; echo -e "┃ $* "; echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }

log_header "FLOW 1: BẢO MẬT SSH (PERMIT ROOT LOGIN)"

# 1. LÀM SAI (BREAK)
log_info "BƯỚC 1: Cố tình cấu hình SAI (Cho phép Root Login)..."
sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd
echo -e "   -> Trạng thái hiện tại: $(grep "^PermitRootLogin" /etc/ssh/sshd_config)"

# 2. KIỂM TRA (AUDIT)
log_info "BƯỚC 2: Chạy Audit để phát hiện lỗi..."
sudo -E bash "$DIR/cis-tool.sh" audit --section os | grep -Ei "ID .*3" -A 5

# 3. VÁ LỖI (HARDEN)
log_info "BƯỚC 3: Kích hoạt Hardening để tự động vá lỗi..."
sudo -E bash "$DIR/cis-tool.sh" harden --section os > /dev/null
log_ok "Lệnh Hardening đã được thực thi."

# 4. XÁC NHẬN (VERIFY)
log_info "BƯỚC 4: Kiểm tra lại trạng thái cuối cùng..."
sudo -E bash "$DIR/cis-tool.sh" audit --section os | grep -Ei "ID .*3" -A 5

# 5. XUẤT BÁO CÁO (OUTPUT)
log_info "BƯỚC 5: Khởi tạo báo cáo cho riêng hạng mục này..."
# Chỉ chạy audit cục bộ để lấy JSON mới nhất cho báo cáo
sudo bash "$DIR/cis-tool.sh" audit --section os > /dev/null
python3 "$DIR/scripts/export_excel.py"
log_ok "Báo cáo Excel đã sẵn sàng: CIS_Cassandra_Compliance_Report.xlsx"

log_header "KẾT THÚC FLOW 1: HỆ THỐNG ĐÃ AN TOÀN & CÓ BÁO CÁO"
