# Hướng dẫn Kiểm thử Thủ công 4 Demos (Từng bước chi tiết)

Tài liệu này cung cấp các lệnh terminal chính xác để bạn tự chạy và kiểm chứng từng bước của cả 4 Demo bảo mật từ máy quản trị **Master VM** (`cassandra@cis-cassandra-master`).

---

## 🔒 DEMO 1: BẢO MẬT SSH (PERMIT ROOT LOGIN) - TARGET NODE 1 (10.0.1.11)

### **Bước 1: Phá cấu hình bảo mật trên Node 1**
Cho phép kết nối bằng tài khoản `root` và restart SSH service trên Node 1:
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.11 "sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
```
*Kiểm tra trạng thái cấu hình hiện tại:*
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.11 "grep '^PermitRootLogin' /etc/ssh/sshd_config"
# Mong đợi output: PermitRootLogin yes
```

### **Bước 2: Quét kiểm toán (Audit) phát hiện lỗi**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.11 "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*3" -A 5
```
*Kết quả:* Trạng thái hiển thị `[WARN] Vi phạm an ninh detected!` vì `Evidence: yes`.

### **Bước 3: Tự động vá lỗi (Harden)**
Khóa quyền truy cập root SSH tự động trên Node 1:
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.11 "sudo bash ~/cis-tool/cis-tool.sh harden --section os"
```

### **Bước 4: Xác minh lại sau khắc phục**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.11 "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*3" -A 5
```
*Kết quả:* Dòng `Evidence: no` và `[OK] Hạng mục này đạt yêu cầu.` xuất hiện.

### **Bước 5: Xuất báo cáo Excel đơn lẻ**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.11 "sudo NO_JSON= bash ~/cis-tool/cis-tool.sh audit --section os" | grep "^{" > /tmp/cis_results.json
python3 ~/cis-cassandra/scripts/export_excel.py
```
*Kết quả:* Excel report được ghi đè thành công tại thư mục root của Master.

---

## ⚡ DEMO 2: TỐI ƯU KERNEL (SWAPPINESS) - TARGET NODE 2 (10.0.1.12)

### **Bước 1: Đưa cấu hình swappiness về mặc định (Lỗi hiệu năng)**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.12 "sudo sysctl -w vm.swappiness=60"
```
*Kiểm tra thông số hiện tại:*
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.12 "sysctl vm.swappiness"
# Mong đợi output: vm.swappiness = 60
```

### **Bước 2: Quét kiểm toán phát hiện lỗi hiệu năng**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.12 "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*6" -A 5
```
*Kết quả:* Vi phạm được phát hiện do Cassandra yêu cầu `vm.swappiness` cực thấp (nhỏ hơn hoặc bằng 10).

### **Bước 3: Tự động tối ưu hóa hệ thống (Harden)**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.12 "sudo bash ~/cis-tool/cis-tool.sh harden --section os"
```

### **Bước 4: Xác minh lại thông số Swappiness**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.12 "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*6" -A 5
```
*Kết quả:* `vm.swappiness` đã được đưa về cấu hình tối ưu khuyến nghị (`1` hoặc `10`).

### **Bước 5: Xuất báo cáo Excel**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.12 "sudo NO_JSON= bash ~/cis-tool/cis-tool.sh audit --section os" | grep "^{" > /tmp/cis_results.json
python3 ~/cis-cassandra/scripts/export_excel.py
```

---

## 🌐 DEMO 3: BẢO MẬT MẠNG (DISABLE IPV6) - TARGET NODE 3 (10.0.1.13)

### **Bước 1: Bật IPv6 (Không khuyến nghị cho hạ tầng Cassandra)**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.13 "sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"
```
*Kiểm tra trạng thái hiện tại:*
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.13 "sysctl net.ipv6.conf.all.disable_ipv6"
# Mong đợi output: 0 (có nghĩa là IPv6 đang được bật)
```

### **Bước 2: Quét kiểm toán phát hiện vi phạm bảo mật mạng**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.13 "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*8" -A 5
```

### **Bước 3: Tự động vô hiệu hóa IPv6 (Harden)**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.13 "sudo bash ~/cis-tool/cis-tool.sh harden --section os"
```

### **Bước 4: Xác minh lại trạng thái vô hiệu hóa mạng**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.13 "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*8" -A 5
```
*Kết quả:* IPv6 đã được vô hiệu hóa hoàn toàn (`disable_ipv6 = 1`).

### **Bước 5: Xuất báo cáo Excel**
```bash
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.13 "sudo NO_JSON= bash ~/cis-tool/cis-tool.sh audit --section os" | grep "^{" > /tmp/cis_results.json
python3 ~/cis-cassandra/scripts/export_excel.py
```

---

## 📊 DEMO 4: QUY TRÌNH KIỂM TOÁN VÀ KHẮC PHỤC TOÀN CỤM (CLUSTER FLOW)

### **Bước 1: Gây lỗi đồng thời trên cả 3 Node database**
```bash
# Phá cấu hình SSH trên Node 1 (10.0.1.11)
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.11 "sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"

# Phá cấu hình Swappiness trên Node 2 (10.0.1.12)
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.12 "sudo sysctl -w vm.swappiness=60"

# Phá cấu hình IPv6 trên Node 3 (10.0.1.13)
ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no cassandra@10.0.1.13 "sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"
```
*(Nếu bạn kiểm tra giao diện Dashboard UI lúc này, điểm số của cả 3 Node sẽ đồng loạt giảm sút)*

### **Bước 2: Chạy kiểm toán tập trung toàn cụm từ Master VM**
```bash
sudo bash ~/cis-cassandra/cis-tool.sh audit cluster --section os
```
*(Lệnh này tự động dispatch quét SSH song song và lưu kết quả JSON tổng hợp tại `scripts/reports/cluster_results.json`)*

### **Bước 3: Chạy khắc phục tự động tập trung toàn cụm từ Master VM**
```bash
sudo bash ~/cis-cassandra/cis-tool.sh harden cluster --section os
```
*(Lệnh này kết nối an toàn và tự động khôi phục cấu hình bảo mật tối ưu trên toàn bộ các DB nodes)*

### **Bước 4: Chạy kiểm toán xác nhận lại trạng thái toàn cụm**
```bash
sudo bash ~/cis-cassandra/cis-tool.sh audit cluster --section os
```
*(Điểm số trên Dashboard UI lúc này sẽ phục hồi về trạng thái an toàn tuyệt đối)*

### **Bước 5: Xuất báo cáo Excel toàn cụm chuyên nghiệp**
```bash
python3 ~/cis-cassandra/scripts/export_excel.py
```
*(File Excel xuất ra chứa thông tin đầy đủ, phân loại màu sắc an toàn trực quan theo từng IP Node trong cụm)*
