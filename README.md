# README - Demo CIS Cassandra Security Automator

Tài liệu này tập trung vào phần demo của dự án. Mục tiêu là mô tả rõ cách hệ thống phát hiện lỗi cấu hình, tự động khắc phục, kiểm tra lại kết quả và xuất báo cáo cho từng lần trình diễn.

## I. Thông tin chung cho demo

### 1. Mục tiêu chung

Demo được xây dựng để chứng minh rằng hệ thống có thể kiểm toán và khắc phục các cấu hình không phù hợp với CIS Apache Cassandra 4.0 Benchmark v1.3.0. Nội dung demo đi từ một lỗi cấu hình cụ thể, sau đó kiểm tra bằng công cụ tự động, xử lý bằng cơ chế harden, xác minh lại trạng thái cuối cùng và tổng hợp dữ liệu thành báo cáo.

### 2. Tiêu chuẩn áp dụng

Các demo trong repository bám theo cùng một bộ tiêu chuẩn kiểm tra của CIS Cassandra. Mỗi kiểm tra tập trung vào một hạng mục cấu hình có ảnh hưởng trực tiếp đến an toàn hệ thống, khả năng vận hành và tính ổn định của cụm Cassandra.

### 3. Luồng thực nghiệm chung

Mỗi demo đều đi theo cùng một luồng cơ bản.

1. Gây sai cấu hình hoặc tạo trạng thái không tuân thủ.
2. Chạy audit để phát hiện lỗi và ghi nhận trạng thái hiện tại.
3. Chạy harden để hệ thống tự động sửa cấu hình.
4. Chạy audit lại để xác minh trạng thái đã về đúng chuẩn.
5. Xuất báo cáo để tổng hợp kết quả kiểm tra thành tài liệu cuối cùng.

### 4. Dữ liệu và đầu ra

Kết quả kiểm tra được gom thành các bản ghi có các trường chính như mã kiểm tra, tên kiểm tra, trạng thái, mức độ nghiêm trọng, giá trị hiện tại, giá trị mong đợi và hướng dẫn khắc phục. Script xuất báo cáo `scripts/export_excel.py` sẽ đọc dữ liệu kiểm toán và tạo file `CIS_Cassandra_Compliance_Report.xlsx`. Báo cáo này được trình bày theo từng node, mỗi node tương ứng với một sheet riêng trong file Excel.

### 5. Tóm tắt nhanh các demo

| Demo   | Mục tiêu                    | Cách chạy nhanh                                                                                                      | Đầu ra chính                                   |
| ------ | --------------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Demo 1 | Khóa đăng nhập root qua SSH | `bash demo/1_Live_Fix_Flows/demo_flow_1_ssh.sh`                                                                      | Audit OS.3, harden SSH, file báo cáo Excel     |
| Demo 2 | Tối ưu `vm.swappiness`      | `bash demo/1_Live_Fix_Flows/demo_flow_2_kernel.sh`                                                                   | Audit OS.6, harden kernel, file báo cáo Excel  |
| Demo 3 | Vô hiệu hóa IPv6            | `bash demo/1_Live_Fix_Flows/demo_flow_3_network.sh`                                                                  | Audit OS.8, harden mạng, file báo cáo Excel    |
| Demo 4 | Audit và khắc phục theo cụm | `bash demo/2_Cluster_Audit_Report/demo_full_cluster_flow.sh` rồi `bash demo/2_Cluster_Audit_Report/demo_3_verify.sh` | Kết quả theo từng node, báo cáo tổng hợp Excel |

## II. Các demo

### 1. Demo nhỏ 1: Bảo mật SSH cho quyền đăng nhập root

Mục tiêu của demo này là chứng minh hệ thống phát hiện được việc cho phép đăng nhập root qua SSH và tự động đưa cấu hình về trạng thái an toàn. Đây là một kiểm tra quan trọng vì root login trực tiếp làm tăng rủi ro chiếm quyền điều khiển máy chủ.

Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/1_Live_Fix_Flows/demo_flow_1_ssh.sh
```

Luồng thực hiện của demo được triển khai theo đúng trình tự trong script `demo/1_Live_Fix_Flows/demo_flow_1_ssh.sh`.

1. Gây lỗi chủ đích bằng lệnh `sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config` vì kiểm tra OS.3 đọc cấu hình SSH từ tệp này. Khi đổi trực tiếp giá trị thành `yes`, hệ thống tạo ra trạng thái sai rõ ràng để audit có thể nhận diện.
2. Khởi động lại dịch vụ SSH bằng `sudo systemctl restart sshd` vì dịch vụ SSH chỉ áp dụng cấu hình mới sau khi được nạp lại. Nếu không restart, lệnh audit có thể vẫn thấy trạng thái cũ và kết quả kiểm tra sẽ không phản ánh đúng thay đổi vừa tạo.
3. Chạy audit bằng `sudo -E bash "$DIR/cis-tool.sh" audit --section os | grep -Ei "ID .*3" -A 5` để lọc riêng kết quả OS.3. Lệnh này vừa kiểm tra trạng thái thực tế, vừa rút gọn đầu ra để người xem tập trung vào đúng vi phạm đang trình diễn.
4. Chạy harden bằng `sudo -E bash "$DIR/cis-tool.sh" harden --section os` vì script harden chứa logic sửa lỗi tự động cho OS.3. Cơ chế này dùng `sed` để ghi lại `PermitRootLogin no`, sau đó dịch vụ SSH được nạp lại để cấu hình mới có hiệu lực.
5. Chạy audit lần nữa bằng cùng kiểm tra OS.3 để xác nhận trạng thái đã trở về đúng chuẩn. Bước này quan trọng vì nó chứng minh thay đổi không chỉ sửa trên tệp cấu hình mà còn có hiệu lực thực sự trên hệ thống.
6. Xuất báo cáo Excel bằng `python3 "$DIR/scripts/export_excel.py"` để lưu kết quả cuối cùng thành tài liệu có thể đối chiếu. Báo cáo này giúp ghi lại trạng thái trước và sau khắc phục trong một định dạng thống nhất.

Kết quả mong đợi của demo này là kiểm tra OS.3 chuyển từ trạng thái không tuân thủ sang tuân thủ. Trong dữ liệu tổng hợp của repo, kiểm tra này kết thúc ở trạng thái `PASS` với giá trị hiện tại là `no`, đúng với cấu hình yêu cầu.

### 2. Demo nhỏ 2: Tối ưu kernel với `vm.swappiness`

Mục tiêu của demo này là chứng minh hệ thống nhận ra một tham số kernel không phù hợp với môi trường cơ sở dữ liệu và đưa nó về mức an toàn cho Cassandra. Tham số `vm.swappiness` ảnh hưởng trực tiếp đến cách Linux dùng swap, nên giá trị quá cao có thể làm giảm hiệu năng và làm hệ thống thiếu ổn định.

Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/1_Live_Fix_Flows/demo_flow_2_kernel.sh
```

Luồng thực hiện của demo này nằm trong `demo/1_Live_Fix_Flows/demo_flow_2_kernel.sh`.

1. Gây sai cấu hình bằng lệnh `sudo sysctl -w vm.swappiness=60`.
2. Kiểm tra lại giá trị hiện tại bằng `sysctl vm.swappiness` để xác nhận trạng thái sai đã được nạp vào kernel.
3. Chạy audit bằng `sudo -E bash "$DIR/cis-tool.sh" audit --section os | grep -Ei "ID .*6" -A 5` để kiểm tra riêng mục OS.6.
4. Chạy harden bằng `sudo -E bash "$DIR/cis-tool.sh" harden --section os` vì script này có sẵn logic đưa `vm.swappiness` về `1`.
5. Chạy audit lại để xác minh rằng kernel đã chấp nhận giá trị mới và kiểm tra OS.6 chuyển sang `PASS`.
6. Xuất báo cáo Excel bằng `python3 "$DIR/scripts/export_excel.py"` để lưu lại kết quả cuối cùng.

Điểm đáng chú ý của demo này là giá trị `60` không chỉ là một con số sai cấu hình, mà còn là giá trị có thể làm hệ thống ưu tiên swap sớm hơn mức cần thiết. Vì vậy bước harden không chỉ sửa trạng thái kiểm tra, mà còn nhằm giữ cho Cassandra ưu tiên sử dụng RAM ổn định hơn.

Kết quả mong đợi của demo này là tham số kernel đổi từ giá trị không phù hợp sang `1`. Trong báo cáo tổng hợp của repo, kiểm tra OS.6 đã đạt trạng thái `PASS` và giá trị thực tế là `1`.

### 3. Demo nhỏ 3: Vô hiệu hóa IPv6

Mục tiêu của demo này là chứng minh hệ thống kiểm tra và tắt IPv6 khi môi trường Cassandra không yêu cầu giao thức này. Việc vô hiệu hóa IPv6 giúp giảm bề mặt tấn công và tránh các cấu hình mạng không cần thiết trong kịch bản trình diễn.

Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/1_Live_Fix_Flows/demo_flow_3_network.sh
```

Luồng thực hiện nằm trong `demo/1_Live_Fix_Flows/demo_flow_3_network.sh`.

1. Gây sai cấu hình bằng lệnh `sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0`.
2. Kiểm tra giá trị hiện hành bằng `sysctl -n net.ipv6.conf.all.disable_ipv6` để nhìn đúng giá trị kernel đang áp dụng.
3. Chạy audit bằng `sudo -E bash "$DIR/cis-tool.sh" audit --section os | grep -Ei "ID .*8" -A 5` để tập trung vào kiểm tra OS.8.
4. Chạy harden bằng `sudo -E bash "$DIR/cis-tool.sh" harden --section os` vì nhánh harden của check này đặt lại `disable_ipv6=1`.
5. Chạy audit lại để kiểm tra IPv6 đã bị vô hiệu hóa ở mức kernel.
6. Xuất báo cáo Excel bằng `python3 "$DIR/scripts/export_excel.py"` để ghi nhận kết quả.

Điểm cần nhấn mạnh ở demo này là hệ thống không chỉ kiểm tra trạng thái mạng ở mức ứng dụng, mà kiểm tra trực tiếp tham số kernel. Điều này làm cho kết quả có giá trị hơn vì nó phản ánh đúng trạng thái vận hành của máy, không phải chỉ là cấu hình trên giấy.

Kết quả mong đợi của demo này là kiểm tra OS.8 chuyển sang `PASS` với giá trị `1`. Trong dữ liệu tổng hợp của repo, kiểm tra này đúng là đã ở trạng thái `PASS` sau khi hệ thống thực hiện hardening.

### 4. Demo tổng hợp: Kiểm toán và khắc phục trên cụm ba node

Mục tiêu của demo tổng hợp là chứng minh hệ thống có thể điều phối kiểm toán và khắc phục trên nhiều node cùng lúc. Đây là phần quan trọng nhất của bộ demo vì nó cho thấy công cụ không chỉ sửa một máy đơn lẻ, mà còn có thể xử lý tình trạng sai lệch trên toàn cụm.

Demo này thường được chạy trong môi trường có sẵn SSH tới các node hoặc qua cơ chế điều khiển từ xa được cấu hình trước. Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/2_Cluster_Audit_Report/demo_full_cluster_flow.sh
bash demo/2_Cluster_Audit_Report/demo_3_verify.sh
```

Luồng thực hiện được mô tả trong `demo/2_Cluster_Audit_Report/demo_full_cluster_flow.sh` và `demo/2_Cluster_Audit_Report/demo_3_verify.sh`.

1. Tạo sai lệch trên ba node khác nhau để mô phỏng một cụm đang bị drift cấu hình.
2. Node 1 được đặt SSH ở trạng thái không an toàn bằng cách cho phép root login.
3. Node 2 được bật IPv6 để tạo ra một điểm mở không cần thiết.
4. Node 3 được đặt `vm.swappiness=60` để mô phỏng sai lệch về kernel tuning.
5. Chạy audit cluster bằng `sudo bash "$DIR/cis-tool.sh" audit cluster` để gom kết quả kiểm tra về một điểm điều khiển duy nhất.
6. Chạy harden cluster bằng `sudo bash "$DIR/cis-tool.sh" harden cluster` để script tự sửa từng node theo lỗi tương ứng.
7. Chạy audit lại toàn cụm để kiểm tra tất cả node đã trở về trạng thái an toàn.
8. Xuất báo cáo Excel bằng `python3 "$DIR/scripts/export_excel.py"` để tạo đầu ra cuối cùng theo từng node.

Điểm quan trọng của demo này là hành động trên từng node không giống nhau, nhưng đầu mối điều phối chỉ có một. Điều đó cho thấy hệ thống có khả năng nhận diện sai lệch riêng của từng máy rồi áp dụng đúng biện pháp khắc phục mà không cần người vận hành xử lý thủ công từng node.

Kết quả cuối cùng cho thấy hệ thống xử lý được cả ba lớp vấn đề cùng lúc: bảo mật SSH, cấu hình kernel và chính sách mạng. Phần này cũng là cơ sở để đánh giá khả năng điều phối tập trung và tính nhất quán của báo cáo đầu ra.

## III. Phân tích dữ liệu và kết quả thu được từ các demo

Phần này dùng dữ liệu thật đã được ghi lại trong repository, chủ yếu từ `test_results/combined_audit.csv` và các tệp trong `demo/reports/`. Cách đọc số liệu bên dưới vì vậy nên được xem như phần phân tích dựa trên đầu ra đã lưu, không phải mô tả giả định.

### 1. Cách đọc dữ liệu

Phần phân tích dữ liệu của bộ demo nên được đọc theo ba lớp riêng biệt.

Lớp thứ nhất là trạng thái kiểm tra. Trạng thái cho biết một hạng mục đang `PASS`, `FAIL` hay cần đánh giá thủ công.

Lớp thứ hai là giá trị hiện tại và giá trị mong đợi. Hai giá trị này cho biết hệ thống đang lệch khỏi chuẩn ở đâu.

Lớp thứ ba là biện pháp khắc phục. Phần này cho biết công cụ đã sửa bằng cách nào và vì sao có thể đưa kiểm tra về trạng thái đúng.

### 2. Tổng quan kết quả

Trong báo cáo tổng hợp ở `test_results/combined_audit.csv`, node `10.0.1.11` có 28 kiểm tra được ghi nhận, trong đó 23 kiểm tra ở trạng thái `PASS`, 2 kiểm tra ở trạng thái `FAIL` và 3 kiểm tra cần đánh giá thủ công. Tỷ lệ đạt tự động tương ứng là khoảng 82.1 phần trăm, còn phần chưa đạt là 7.1 phần trăm.

Con số này có ý nghĩa rõ ràng. Nó cho thấy hệ thống đã xử lý được phần lớn cấu hình thường quy, nhưng vẫn còn các hạng mục có tính nền tảng như mã hóa và quản trị quyền mà không thể bỏ qua. Nói cách khác, công cụ đã chứng minh được năng lực vận hành, nhưng kết quả cũng cho thấy đâu là phần cần tiếp tục hoàn thiện nếu muốn nâng mức tuân thủ lên cao hơn.

### 3. Phân tích hai lỗi còn tồn tại

Hai kiểm tra đang `FAIL` trong báo cáo tổng hợp là `5.1` và `5.2` thuộc nhóm mã hóa.

Kiểm tra `5.1` ghi nhận `internode_encryption: none` thay vì `all or dc`. Điều này có nghĩa là dữ liệu trao đổi giữa các node chưa đi qua lớp mã hóa đầy đủ.

Kiểm tra `5.2` ghi nhận `enabled: false` thay vì `enabled: true`. Điều này cho thấy kết nối từ client vào node vẫn chưa được bật mã hóa TLS như kỳ vọng.

Hai lỗi này đáng chú ý vì chúng không chỉ ảnh hưởng đến một tham số cục bộ, mà ảnh hưởng đến đường truyền dữ liệu của toàn cụm. Trong bối cảnh cơ sở dữ liệu phân tán, lớp truyền tải là nơi mà dữ liệu dễ bị đọc lén hoặc can thiệp nếu không được bảo vệ đúng mức. Vì vậy, phần này của báo cáo cho thấy hệ thống kiểm tra đúng hướng, nhưng mức độ an toàn toàn diện vẫn còn phụ thuộc vào việc hoàn thiện cấu hình mã hóa.

### 4. Các mục cần đánh giá thủ công

Ba mục cần đánh giá thủ công là `3.3`, `3.7` và `3.8`.

Nội dung của chúng liên quan đến rà soát vai trò, quyền và superuser. Các mục này không thể chỉ kết luận bằng một phép kiểm tra cấu hình đơn giản, mà cần đọc thêm từ hệ thống và xem lại phạm vi quyền thực tế.

Ý nghĩa của nhóm này là bộ demo không cố ép mọi thứ thành tự động hoàn toàn. Thay vào đó, hệ thống phân tách đúng phần nào có thể đo bằng script và phần nào cần người đánh giá xác nhận bằng truy vấn hoặc quan sát bổ sung. Cách làm này phù hợp với một báo cáo nghiên cứu vì nó phản ánh đúng giới hạn của tự động hóa.

### 5. Kết quả của ba demo nhỏ

Đối với ba demo nhỏ, dữ liệu báo cáo cho thấy các kiểm tra OS.3, OS.6 và OS.8 đều đạt `PASS` sau khi harden.

Kiểm tra SSH trả về `no`.

Kiểm tra `vm.swappiness` trả về `1`.

Kiểm tra IPv6 trả về `1`.

Ba kết quả này có ý nghĩa khác nhau nhưng cùng một bản chất: hệ thống không chỉ sửa tệp cấu hình, mà còn đưa giá trị đang vận hành trên máy trở về đúng chuẩn. Đây là điểm quan trọng nhất của luồng demo vì nó chứng minh harden không chỉ làm đúng về mặt văn bản cấu hình, mà còn làm đúng về trạng thái đang hoạt động.

Nếu nhìn theo góc độ trình diễn, demo SSH là minh chứng cho việc chặn một cửa vào nguy hiểm. Demo kernel cho thấy hệ thống xử lý được một tham số ảnh hưởng đến hiệu năng vận hành. Demo IPv6 cho thấy hệ thống biết loại bỏ một bề mặt tấn công không cần thiết. Ba kết quả đó kết hợp lại tạo thành một bức tranh đầy đủ hơn về năng lực khắc phục của công cụ.

### 6. Ý nghĩa của demo tổng hợp

Đối với demo tổng hợp, giá trị của báo cáo nằm ở khả năng gom kết quả theo từng node.

Mỗi node được đọc như một đơn vị riêng, nên người đánh giá có thể thấy ngay node nào còn lỗi, lỗi gì và cần sửa ở đâu. Cách trình bày này giúp việc theo dõi trạng thái cụm Cassandra rõ ràng hơn và thuận tiện hơn khi đối chiếu giữa các lần chạy demo.

Nó cũng cho thấy cùng một bộ công cụ nhưng mỗi node có thể ở trạng thái khác nhau, nên báo cáo phải giữ đủ chi tiết để tránh mất ngữ cảnh. Điều này đặc biệt quan trọng với một cụm phân tán vì kết quả tổng thể chỉ có ý nghĩa khi đọc được cả trạng thái riêng lẻ của từng máy.

### 7. Kết luận phân tích

Từ góc độ báo cáo khoa học, kết quả quan trọng nhất của bộ demo không chỉ là số lượng kiểm tra đạt hay không đạt. Quan trọng hơn là hệ thống cho thấy được chu trình xử lý hoàn chỉnh: phát hiện sai cấu hình, sửa cấu hình, xác minh lại, rồi xuất kết quả thành dữ liệu có thể lưu trữ và đọc lại.

Nói cách khác, giá trị của bộ demo nằm ở khả năng biến một thay đổi cấu hình rời rạc thành một chuỗi bằng chứng có thể theo dõi, đối chiếu và dùng lại cho báo cáo. Đây là điều làm cho phần demo có giá trị nghiên cứu rõ ràng hơn, thay vì chỉ là một danh sách lệnh chạy thành công.

## IV. Kết luận demo

Các demo trong dự án cho thấy hệ thống có thể đi trọn một vòng kiểm toán và khắc phục theo cách rõ ràng, nhất quán và có thể theo dõi bằng báo cáo. Ba demo nhỏ chứng minh từng chính sách riêng lẻ có thể được phát hiện và sửa tự động. Demo tổng hợp chứng minh hệ thống còn có thể làm việc trên nhiều node cùng lúc và tổng hợp kết quả về một báo cáo chung.

Kết quả chính của bộ demo là xác nhận mô hình hoạt động ổn định theo đúng luồng: tạo lỗi, phát hiện lỗi, khắc phục, kiểm tra lại và xuất báo cáo. Đây là phần thể hiện rõ nhất giá trị thực tế của dự án trong bối cảnh nghiên cứu và trình diễn hệ thống bảo mật cho Cassandra.
