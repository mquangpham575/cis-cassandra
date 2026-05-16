#!/usr/bin/env bash
# Demo 2: Quét toàn cụm và Xuất báo cáo Excel
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
source "$DIR/scripts/lib/common.sh"

log_header "DEMO 2: TỔNG HỢP BÁO CÁO TUÂN THỦ TOÀN CỤM (3 NODES)"

log_info "Bước 1: Đang kích hoạt tiến trình quét Audit trên toàn bộ Cluster..."
sudo bash "$DIR/cis-tool.sh" audit cluster

log_info "Bước 2: Đang tổng hợp dữ liệu và khởi tạo file Báo cáo Excel..."
python3 "$DIR/scripts/export_excel.py"

log_ok "Báo cáo chuyên nghiệp đã được tạo: CIS_Cassandra_Compliance_Report.xlsx"
log_header "HOÀN TẤT QUY TRÌNH KIỂM TOÁN"
