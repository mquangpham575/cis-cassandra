# CHI TIẾT PHÂN CÔNG NHIỆM VỤ DỰ ÁN (TIẾN ĐỘ 4 TUẦN)

## 1. Thành viên 1 – Infrastructure & DevOps (Nền tảng hạ tầng)

**Vai trò:** Chịu trách nhiệm thiết lập và quản lý toàn bộ hạ tầng kỹ thuật. Đây là nhiệm vụ ưu tiên (Unblock-first) nhằm đảm bảo môi trường thực thi cho toàn bộ đội ngũ phát triển.

### Thiết lập cụm cơ sở dữ liệu Cassandra

- Khởi tạo 03 máy ảo (VM) Ubuntu 22.04 với cấu hình tối thiểu 4GB RAM và 2 vCPU.
- Cấu hình địa chỉ IP tĩnh trong dải nội bộ từ 192.168.56.11 đến 192.168.56.13.
- Cài đặt môi trường thực thi cơ bản bao gồm OpenJDK 8, Python 3.10 và Apache Cassandra 4.0.x.
- Cấu hình tập tin cassandra.yaml với các thông số: Cluster Name, Seed Provider, Listen Address và RPC Address.
- Quản lý và thông các cổng dịch vụ trên Firewall: 7000 (Gossip), 9042 (CQL), 7199 (JMX) và 22 (SSH).

### Triển khai hạ tầng dưới dạng mã (Infrastructure as Code - IaC)

- Xây dựng bộ kịch bản Terraform để tự động hóa quy trình khởi tạo và cấu hình VM đồng nhất.
- Sử dụng Terraform Cloud hoặc S3 làm Backend để quản lý và chia sẻ State giữa các thành viên.

### Bảo mật và Kết nối từ xa

- Triển khai giải pháp WireGuard VPN trên Gateway để thiết lập kênh truy cập bảo mật cho đội ngũ.
- Sử dụng Infisical để lưu trữ và quản lý tập trung các thông tin nhạy cảm (SSH keys, mật khẩu hệ thống).
- Cài đặt GitHub Actions Self-hosted Runner trên Gateway VPN để thực thi quy trình CI/CD trong mạng nội bộ.

### Hệ thống giám sát (Observability)

- Cấu hình Prometheus để thu thập JMX metrics từ các node Cassandra.
- Thiết lập Grafana Dashboard hiển thị trực quan các chỉ số vận hành trọng yếu: Heap memory, Latency, Disk usage và trạng thái hoạt động của cụm node.

---

## 2. Thành viên 2 – CIS Scripting & Hardening (Logic bảo mật)

**Vai trò:** Phát triển logic kiểm tra và khắc phục lỗ hổng bảo mật theo tiêu chuẩn quốc tế. Sản phẩm của nhiệm vụ này là nguồn dữ liệu đầu vào cốt lõi cho Backend và Dashboard.

### Xây dựng thư viện lõi (Foundation)

- Hoàn thiện tập tin common.sh chứa các hàm tiện ích: Nhật ký hệ thống (Logging), định dạng kết quả chuẩn JSON, kiểm tra đặc quyền root và thực thi lệnh từ xa.

### Triển khai danh mục Security Checks (30+ Checks)

- Thực thi đầy đủ 20 hạng mục kiểm tra theo tiêu chuẩn CIS Apache Cassandra 4.0 Benchmark v1.3.0.
- Bổ sung các hạng mục kiểm tra tùy chỉnh cho lớp hệ điều hành (OS-level hardening) như quyền hạn tập tin và cấu hình bảo mật SSH.
- Áp dụng cấu trúc bắt buộc cho mỗi hạng mục kiểm tra bao gồm 03 giai đoạn: audit (phát hiện), harden (khắc phục tự động), và verify (xác nhận lại).

### Tích hợp các lớp bảo mật thực tế

- **Xác thực và Phân quyền**: Kích hoạt cơ chế PasswordAuthenticator và CassandraAuthorizer trong cấu hình hệ thống.
- **Nhật ký bảo mật**: Kích hoạt Audit Logging để lưu vết toàn bộ hoạt động truy cập và thao tác dữ liệu.
- **Mã hóa dữ liệu**: Cấu hình mã hóa TLS cho luồng dữ liệu nội bộ và kết nối từ phía ứng dụng khách (Client).
- **Kiểm tra thủ công**: Trích xuất dữ liệu thực tế cho các hạng mục kiểm tra Manual để phục vụ công tác thẩm định.

### Phát triển công cụ điều phối (cis-tool.sh)

- Xây dựng giao diện dòng lệnh hỗ trợ chạy audit theo từng phân đoạn hoặc thực thi song song trên toàn bộ các node.
- Đảm bảo cấu trúc dữ liệu đầu ra tuân thủ định dạng JSON Schema đã thống nhất.
- Quản lý mã thoát (Exit code) chính xác (0 cho Pass, 1 cho Fail) để tích hợp vào hàng rào bảo mật CI/CD.

---

## 3. Thành viên 3 – Backend API & System Integration (Tích hợp hệ thống)

**Vai trò:** Xây dựng hệ thống API trung gian để điều phối các kịch bản bảo mật và cung cấp dữ liệu xử lý cho giao diện Dashboard.

### Khởi tạo dự án và Mô hình hóa dữ liệu

- Thiết lập dự án FastAPI và định nghĩa các Pydantic models nhằm chuẩn hóa dữ liệu audit/harden.
- Thống nhất JSON Schema với bộ phận Script ngay từ giai đoạn đầu để đảm bảo tính tương thích dữ liệu.

### Xây dựng các API Endpoints

- GET /nodes: Truy xuất danh sách và trạng thái vận hành của các node trong cụm.
- POST /audit/{ip}: Kích hoạt kịch bản kiểm tra bảo mật trên VM thông qua giao thức SSH.
- POST /remediate/{ip}: Thực thi quy trình khắc phục lỗi tự động trên node mục tiêu.
- GET /report: Tổng hợp và tính toán điểm số tuân thủ bảo mật (Compliance Score) của toàn hệ thống.

### Xử lý dữ liệu thời gian thực và SSH

- Sử dụng thư viện AsyncSSH để quản lý các kết nối bất đồng bộ tới hệ thống máy ảo.
- Triển khai giao thức WebSocket (/ws/audit/) để truyền tải trực tiếp luồng nhật ký thực thi (Stream) từ VM về trình duyệt người dùng.

### Đảm bảo chất lượng và Giám sát

- Xây dựng Proxy endpoint để trích xuất dữ liệu metrics từ hệ thống Prometheus cho Frontend.
- Thực hiện Unit tests cho các router và dịch vụ xử lý bằng pytest.
- Cung cấp tài liệu API tự động thông qua giao diện Swagger UI tại đường dẫn /docs.

---

## 4. Thành viên 4 – Frontend Dashboard & CI/CD Pipeline (Giao diện và Quy trình)

**Vai trò:** Phát triển giao diện quản trị trực quan và thiết lập quy trình tự động hóa bảo mật (Security Gate) trong chu trình phát triển.

### Phát triển giao diện người dùng (SPA)

- Khởi tạo ứng dụng bằng Vite và React 18, sử dụng Tailwind CSS và bộ thành phần UI chuyên nghiệp từ shadcn/ui.
- **Trang Dashboard**: Hiển thị tổng quan trạng thái hạ tầng và biểu đồ điểm số bảo mật (Score Gauge) thời gian thực.
- **Trang Compliance**: Cung cấp bảng chi tiết kết quả kiểm tra với tính năng lọc theo trạng thái và mức độ nghiêm trọng.
- **Trang Audit Live**: Giao diện Terminal mô phỏng hiển thị nhật ký thực thi trực tiếp qua WebSocket.
- **Trang Monitoring**: Tích hợp các biểu đồ giám sát kỹ thuật được nhúng từ Grafana/Prometheus.

### Quản lý trạng thái và Kết nối dữ liệu

- Xây dựng API Client bằng TypeScript sử dụng Axios và TanStack Query để quản lý đồng bộ dữ liệu.
- Phát triển Custom hook để xử lý luồng dữ liệu WebSocket và cơ chế tự động kết nối lại khi mất tín hiệu.

### Thiết lập quy trình CI/CD Security

- Cấu hình GitHub Actions Workflow tự động kích hoạt khi phát sinh Pull Request (PR) vào nhánh chính.
- **Security Gate**: Xây dựng bước kiểm tra kết quả audit từ tập tin JSON; thực hiện chặn việc hợp nhất mã nguồn (Block merge) nếu phát hiện vi phạm bảo mật mức độ CRITICAL.
- Thiết lập các quy tắc bảo vệ nhánh (Branch Protection Rules) yêu cầu các bước kiểm tra tự động phải thành công.

### Tích hợp công cụ DevSecOps bổ sung

- Triển khai Trivy để quét lỗ hổng bảo mật trong hệ thống tập tin và Docker image.
- Tích hợp Bandit để thực hiện phân tích mã nguồn tĩnh (SAST) cho mã nguồn Backend.
- Cấu hình ESLint Security Plugin nhằm kiểm soát các rủi ro bảo mật trong mã nguồn Frontend.
