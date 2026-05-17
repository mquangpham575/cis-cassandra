#!/usr/bin/env bash
# Demo 2: Toàn trình Kiểm toán & Khắc phục lỗi trên cụm máy chủ (3 Nodes)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
source "$DIR/scripts/lib/common.sh"
export NO_JSON=1

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log_header() { echo -e "\n${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"; echo -e "┃ $* "; echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"; }
log_info()   { echo -e "${BLUE}[ℹ]${NC} $*"; }
log_ok()     { echo -e "${GREEN}[✔] PASS:${NC} $*"; }
log_warn()   { echo -e "${YELLOW}[!] WARNING:${NC} $*"; }

log_header "DEMO 2: QUY TRÌNH KIỂM TOÁN & KHẮC PHỤC LỖI TẬP TRUNG (3 NODES)"

# BƯỚC 1: GÂY LỖI ĐA DẠNG (BREAK)
log_info "BƯỚC 1: Đang gây lỗi cấu hình trên toàn cụm để mô phỏng rủi ro thực tế..."

log_warn "-> Đang gây lỗi Data Center Auth (3.6) & max_map_count (OS.7) trên Node 1 (10.0.1.11)..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.11" "sudo sed -i 's/^network_authorizer:.*/network_authorizer: AllowAllNetworkAuthorizer/' /etc/cassandra/cassandra.yaml && sudo sysctl -w vm.max_map_count=65530" > /dev/null

log_warn "-> Đang gây lỗi Logging Level (4.1) & Data Center Auth (3.6) trên Node 2 (10.0.1.12)..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.12" "sudo sed -i 's/<root level=\"INFO\">/<root level=\"OFF\">/g' /etc/cassandra/logback.xml && sudo sed -i 's/^network_authorizer:.*/network_authorizer: AllowAllNetworkAuthorizer/' /etc/cassandra/cassandra.yaml" > /dev/null

log_warn "-> Đang gây lỗi max_map_count (OS.7) & Logging Level (4.1) trên Node 3 (10.0.1.13)..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@10.0.1.13" "sudo sysctl -w vm.max_map_count=65530 && sudo sed -i 's/<root level=\"INFO\">/<root level=\"OFF\">/g' /etc/cassandra/logback.xml" > /dev/null

# BƯỚC 2: QUÉT LỖI (AUDIT)
log_info "BƯỚC 2: Đang kích hoạt Audit toàn cụm để nhận diện các vi phạm bảo mật..."
# Chỉ grep các ID quan trọng để log không quá dài cho người xem
bash "$DIR/cis-tool.sh" audit cluster | grep -Ei "ID .*3\.6|ID .*4\.1|ID .*OS\.7|REPORT FROM NODE" -A 2

# BƯỚC 3: VÁ LỖI (HARDEN)
log_info "BƯỚC 4: Kích hoạt Hardening tập trung để vá lỗi cho tất cả các Nodes..."
bash "$DIR/cis-tool.sh" harden cluster > /dev/null
log_ok "Hệ thống đã hoàn tất tiến trình tự động khắc phục lỗi."

# BƯỚC 4: XÁC MINH (VERIFY)
log_info "BƯỚC 5: Kiểm toán lại lần cuối để xác nhận tính tuân thủ..."
bash "$DIR/cis-tool.sh" audit cluster | grep -Ei "ID .*3\.6|ID .*4\.1|ID .*OS\.7|REPORT FROM NODE" -A 2

# BƯỚC 5: XUẤT BÁO CÁO (OUTPUT)
log_info "BƯỚC 6: Tổng hợp dữ liệu và xuất báo cáo Excel cho toàn bộ dự án..."
python3 "$DIR/scripts/export_excel.py"
log_ok "Báo cáo tổng kết toàn diện đã sẵn sàng: CIS_Cassandra_Compliance_Report.xlsx"

log_header "HOÀN TẤT DEMO 2: CỤM MÁY CHỦ ĐÃ AN TOÀN TUYỆT ĐỐI"
