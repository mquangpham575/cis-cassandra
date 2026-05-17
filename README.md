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

| Demo   | Mục tiêu                    | Node               | Cách chạy nhanh                                                                                                   | Đầu ra chính                                     |
| ------ | --------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| Demo 1 | Khóa đăng nhập root qua SSH | Node 1 (10.0.1.11) | `bash demo/1_Live_Fix_Flows/demo_flow_1_ssh.sh`                                                                   | Audit OS.3 qua SSH, harden SSH, báo cáo Excel    |
| Demo 2 | Tối ưu `vm.swappiness`      | Node 1 (10.0.1.11) | `bash demo/1_Live_Fix_Flows/demo_flow_2_kernel.sh`                                                                | Audit OS.6 qua SSH, harden kernel, báo cáo Excel |
| Demo 3 | Vô hiệu hóa IPv6            | Node 1 (10.0.1.11) | `bash demo/1_Live_Fix_Flows/demo_flow_3_network.sh`                                                               | Audit OS.8 qua SSH, harden mạng, báo cáo Excel   |
| Demo 4 | Audit và khắc phục theo cụm | Node 1, 2, 3       | `bash demo/2_Cluster_Audit_Report/demo_full_cluster_flow.sh && bash demo/2_Cluster_Audit_Report/demo_3_verify.sh` | Audit cụm, harden cụm, kết quả theo từng node    |

## II. Các demo

Trước khi chạy bất kỳ demo nào, cần đảm bảo các biến SSH môi trường đã được thiết lập. Các biến này thường được khai báo trong `scripts/lib/common.sh`. Để sử dụng các lệnh ví dụ bên dưới, hãy thiết lập:

```bash
export SSH_KEY="$HOME/.ssh/cis_key"        # hoặc đường dẫn tới SSH private key
export SSH_USER="cassandra"                # hoặc tên user SSH trên các node
```

Nếu chạy các script demo từ thư mục gốc (ví dụ: `bash demo/1_Live_Fix_Flows/demo_flow_1_ssh.sh`), các biến này được tự động load từ `scripts/lib/common.sh`.

### 1. Demo nhỏ 1: Bảo mật SSH cho quyền đăng nhập root

Mục tiêu của demo này là chứng minh hệ thống có thể phát hiện được việc cho phép đăng nhập root qua SSH trên một node DB cụ thể và tự động đưa cấu hình về trạng thái an toàn. Demo này tác động trên Node 1 (10.0.1.11) qua SSH, mô phỏng quá trình bảo mật một cụm Cassandra trong thực tế.

Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/1_Live_Fix_Flows/demo_flow_1_ssh.sh
```

Luồng thực hiện của demo được triển khai theo đúng trình tự trong script `demo/1_Live_Fix_Flows/demo_flow_1_ssh.sh`.

1. Gây lỗi chủ đích trên Node 1 bằng lệnh SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"`. Bước này sửa đổi cấu hình SSH trên Node 1 để cho phép đăng nhập root, tạo ra trạng thái sai rõ ràng mà hệ thống kiểm tra sẽ phát hiện.
   - _Xác minh lỗi đã được gây:_ `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "grep '^PermitRootLogin' /etc/ssh/sshd_config"` → mong đợi output: `PermitRootLogin yes`
2. Chạy audit trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*3" -A 5`. Lệnh này kiểm tra trạng thái thực tế trên Node 1 và lọc riêng kết quả OS.3 để người xem tập trung vào vi phạm đang trình diễn.
3. Chạy harden trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo bash ~/cis-tool/cis-tool.sh harden --section os"`. Lệnh này thực thi logic sửa lỗi tự động, dùng `sed` để ghi lại `PermitRootLogin no` và khởi động lại dịch vụ SSH để cấu hình mới có hiệu lực trên Node 1.
4. Chạy audit lại trên Node 1 để xác nhận rằng kiểm tra OS.3 đã chuyển sang `PASS`. Bước này chứng minh rằng thay đổi không chỉ sửa trên tệp cấu hình mà còn có hiệu lực thực sự khi dịch vụ SSH hoạt động.
5. Xuất báo cáo Excel bằng lệnh `python3 "$DIR/scripts/export_excel.py"` để tổng hợp kết quả từ Node 1 thành tài liệu có thể đối chiếu.

Kết quả mong đợi của demo này là kiểm tra OS.3 chuyển từ trạng thái `FAIL` sang `PASS` với giá trị hiện tại là `no`, đúng với cấu hình yêu cầu. Sự thay đổi này được thực hiện trực tiếp trên Node 1 thông qua SSH, giúp chứng minh rằng công cụ có khả năng điều phối bảo mật trên từng node trong cụm.

### 2. Demo nhỏ 2: Tối ưu kernel với `vm.swappiness`

Mục tiêu của demo này là chứng minh hệ thống nhận ra một tham số kernel không phù hợp với môi trường cơ sở dữ liệu trên một node DB cụ thể và đưa nó về mức an toàn cho Cassandra. Demo này tác động trên Node 1 (10.0.1.11) qua SSH, giúp chứng minh rằng công cụ có thể tối ưu hóa các tham số kernel ảnh hưởng đến hiệu năng vận hành.

Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/1_Live_Fix_Flows/demo_flow_2_kernel.sh
```

Luồng thực hiện của demo này nằm trong `demo/1_Live_Fix_Flows/demo_flow_2_kernel.sh`.

1. Gây sai cấu hình trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo sysctl -w vm.swappiness=60"`. Bước này đưa tham số `vm.swappiness` lên giá trị `60`, một mức cao có thể làm kernel ưu tiên swap sớm hơn mức cần thiết cho cơ sở dữ liệu.
   - _Xác minh lỗi đã được gây:_ `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sysctl vm.swappiness"` → mong đợi output: `vm.swappiness = 60`
2. (Bước này đã được thực hiện ở xác minh lỗi)
3. Chạy audit trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*6" -A 5` để kiểm tra riêng mục OS.6.
4. Chạy harden trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo bash ~/cis-tool/cis-tool.sh harden --section os"`. Lệnh này thực thi logic harden, đưa `vm.swappiness` về giá trị `1` để ưu tiên sử dụng RAM ổn định.
5. Chạy audit lại trên Node 1 để xác minh rằng kiểm tra OS.6 đã chuyển sang `PASS` và kernel đã chấp nhận giá trị mới.
6. Xuất báo cáo Excel bằng `python3 "$DIR/scripts/export_excel.py"` để lưu lại kết quả cuối cùng.

Điểm đáng chú ý của demo này là giá trị `60` không chỉ là một con số sai cấu hình, mà còn là mức độ kernel sẽ ưu tiên swap sớm. Bước harden không chỉ sửa trạng thái kiểm tra, mà còn thực tế cải thiện hiệu năng vận hành của Cassandra trên Node 1.

Kết quả mong đợi của demo này là tham số kernel trên Node 1 đổi từ `60` sang `1`. Kiểm tra OS.6 chuyển sang trạng thái `PASS` với giá trị thực tế là `1`, đúng với cấu hình yêu cầu.

### 3. Demo nhỏ 3: Vô hiệu hóa IPv6

Mục tiêu của demo này là chứng minh hệ thống có thể phát hiện và tắt IPv6 trên một node DB cụ thể khi môi trường Cassandra không yêu cầu giao thức này. Demo này tác động trên Node 1 (10.0.1.11) qua SSH, giúp chứng minh rằng công cụ có thể giảm bề mặt tấn công mạng trên từng node.

Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/1_Live_Fix_Flows/demo_flow_3_network.sh
```

Luồng thực hiện nằm trong `demo/1_Live_Fix_Flows/demo_flow_3_network.sh`.

1. Gây sai cấu hình trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"`. Bước này bật IPv6 trên Node 1, tạo ra một bề mặt mạng không cần thiết.
   - _Xác minh lỗi đã được gây:_ `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sysctl net.ipv6.conf.all.disable_ipv6"` → mong đợi output: `net.ipv6.conf.all.disable_ipv6 = 0`
2. (Bước này đã được thực hiện ở xác minh lỗi)
3. Chạy audit trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo bash ~/cis-tool/cis-tool.sh audit --section os" | grep -Ei "ID .*8" -A 5` để kiểm tra riêng OS.8.
4. Chạy harden trên Node 1 bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo bash ~/cis-tool/cis-tool.sh harden --section os"`. Lệnh này thực thi logic harden, đặt `disable_ipv6=1` để vô hiệu hóa IPv6.
5. Chạy audit lại trên Node 1 để kiểm tra rằng IPv6 đã bị vô hiệu hóa ở mức kernel và OS.8 chuyển sang `PASS`.
6. Xuất báo cáo Excel bằng `python3 "$DIR/scripts/export_excel.py"` để ghi nhận kết quả.

Điểm cần nhấn mạnh ở demo này là hệ thống không chỉ kiểm tra trạng thái mạng ở mức ứng dụng, mà kiểm tra trực tiếp tham số kernel trên Node 1. Điều này làm cho kết quả có giá trị hơn vì nó phản ánh đúng trạng thái vận hành thực tế, không phải chỉ là cấu hình lý thuyết.

Kết quả mong đợi của demo này là tham số `disable_ipv6` trên Node 1 đổi từ `0` sang `1`, và kiểm tra OS.8 chuyển sang `PASS`. Sự thay đổi này được thực hiện trực tiếp trên Node 1 thông qua SSH, chứng minh rằng công cụ có khả năng quản lý bảo mật mạng ở mức kernel.

### 4. Demo tổng hợp: Kiểm toán và khắc phục trên cụm ba node

Mục tiêu của demo tổng hợp là chứng minh hệ thống có thể gây lỗi trên nhiều node khác nhau thông qua SSH, sau đó phát hiện và sửa từng lỗi một cách tập trung. Đây là phần quan trọng nhất của bộ demo vì nó cho thấy công cụ không chỉ xử lý một máy đơn lẻ, mà còn có thể điều phối kiểm toán và khắc phục trên toàn cụm.

Demo này yêu cầu SSH access tới ba node khác nhau. Nếu muốn chạy thủ công từ thư mục gốc của repository, có thể dùng:

```bash
cd /path/to/cis-cassandra
bash demo/2_Cluster_Audit_Report/demo_full_cluster_flow.sh
bash demo/2_Cluster_Audit_Report/demo_3_verify.sh
```

Luồng thực hiện được mô tả trong `demo/2_Cluster_Audit_Report/demo_full_cluster_flow.sh` và `demo/2_Cluster_Audit_Report/demo_3_verify.sh`.

1. Tạo sai lệch đa dạng trên ba node khác nhau để mô phỏng một cụm Cassandra đang vận hành với nhiều vấn đề bảo mật khác nhau.
2. Gây lỗi SSH Root Login trên Node 1 (10.0.1.11) bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.11" "sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"`. Bước này mô phỏng một node cho phép đăng nhập root, tạo ra lỗi kiểm tra OS.3.
3. Gây lỗi IPv6 trên Node 2 (10.0.1.12) bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.12" "sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"`. Bước này bật IPv6 trên Node 2, tạo ra lỗi kiểm tra OS.8.
4. Gây lỗi Swappiness trên Node 3 (10.0.1.13) bằng SSH: `ssh -i "$SSH_KEY" "$SSH_USER@10.0.1.13" "sudo sysctl -w vm.swappiness=60"`. Bước này đặt swappiness cao trên Node 3, tạo ra lỗi kiểm tra OS.6.
5. Chạy audit cluster bằng `bash "$DIR/cis-tool.sh" audit cluster` để gom kết quả kiểm tra từ cả ba node vào một báo cáo chung. Đầu ra sẽ cho thấy từng node có lỗi gì.
6. Chạy harden cluster bằng `bash "$DIR/cis-tool.sh" harden cluster` để script tự sửa từng node theo lỗi tương ứng. Node 1 sẽ khóa SSH root login, Node 2 sẽ vô hiệu hóa IPv6, Node 3 sẽ tối ưu swappiness.
7. Chạy audit lại toàn cụm bằng `bash "$DIR/cis-tool.sh" audit cluster` để kiểm tra tất cả ba node đã trở về trạng thái an toàn và ba kiểm tra OS.3, OS.6, OS.8 đều ở trạng thái `PASS`.
8. Xuất báo cáo Excel bằng `python3 "$DIR/scripts/export_excel.py"` để tạo đầu ra cuối cùng theo từng node, giúp ghi nhận trạng thái toàn cụm.

Điểm quan trọng của demo này là hành động trên từng node khác nhau (SSH gây lỗi khác nhau), nhưng đầu mối điều phối chỉ có một. Hệ thống phát hiện đủng lỗi riêng của từng máy từ audit cluster output, rồi harden cluster áp dụng đúng biện pháp cho từng node mà không cần người vận hành can thiệp thủ công.

Kết quả cuối cùng cho thấy hệ thống xử lý được cả ba lớp vấn đề cùng lúc trên ba node khác nhau: bảo mật SSH, cấu hình mạng và tối ưu kernel. Phần này chứng minh năng lực điều phối tập trung và tính nhất quán của báo cáo đầu ra khi làm việc với cụm máy chủ.

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
