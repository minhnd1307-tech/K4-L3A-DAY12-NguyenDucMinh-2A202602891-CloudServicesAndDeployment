# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Đức Minh  Mã học viên: 2A202602891

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống cụ thể: Khi deploy ứng dụng lên nền tảng Cloud (Render/Railway), người cấu hình quên thêm biến môi trường `AGENT_API_KEY` trong mục Environment. Nếu đặt mặc định là `"changeme"`, ứng dụng vẫn khởi động bình thường và mở cổng công khai ra Internet. Các bot tự động quét mạng có thể dễ dàng đoán ra khóa mặc định này hoặc ai đó phát hiện ra sẽ gọi API miễn phí với khối lượng lớn, làm tiêu tốn ngân sách LLM hàng nghìn USD mà ta không hề hay biết cho đến khi nhận hóa đơn. Ngược lại, khi không có giá trị mặc định, cơ chế Fail Fast kích hoạt: Pydantic ném ngay lỗi `ValidationError` và crash tiến trình ngay lúc deploy. Nhờ đó, ta thấy ngay lỗi đỏ trên log triển khai và kịp thời bổ sung key an toàn trước khi có bất kỳ request nào được tiếp nhận.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log JSON thu được:
> `{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:45:12.345678+00:00", "user_id": "sv-test", "tokens_in": 456, "tokens_out": 45, "cost_usd": 0.0000954}`
> 
> Hai việc làm được với dòng log trên:
> 1. **Thống kê định lượng và truy vấn tự động bằng máy (Log Aggregation & Querying):** Các công cụ như Datadog, Grafana Loki, ELK có thể parse các trường JSON để chạy câu lệnh tổng hợp số liệu thực tế như: `SUM(cost_usd) GROUP BY user_id` để biết user nào tiêu nhiều tiền nhất, hoặc tính tổng token tiêu thụ trong ngày. Dòng log dạng `print("đã trả lời xong")` là văn bản tự do, máy tính không thể trích xuất số liệu hay tính toán số học được.
> 2. **Cảnh báo bất thường (Alerting) & phân tích sự cố theo mốc thời gian chuẩn:** Dựa vào nhãn thời gian chuẩn quốc tế ISO-8601 UTC và định danh `user_id`, hệ thống giám sát có thể đặt ngưỡng cảnh báo tự động (ví dụ: cảnh báo ngay khi chi phí của một user vượt quá $1 trong 5 phút), hoặc dễ dàng ghép nối (correlate) vết hoạt động của user xuyên suốt giữa các microservices.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.02 GB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần dung lượng chênh lệch (~750 MB) bao gồm:
> 1. Image gốc ban đầu dùng base image `python:3.11` đầy đủ, chứa cả hệ điều hành Debian hoàn chỉnh kèm theo rất nhiều công cụ biên dịch (gcc, g++, make), các gói header C/C++ và các tiện ích quản trị không dùng đến khi chạy ứng dụng. Bản Multi-stage sử dụng `python:3.11-slim` đã lược bỏ hầu hết các package nặng này.
> 2. Quá trình multi-stage build phân tách riêng stage `builder` để cài đặt thư viện vào thư mục `/install`, sau đó stage `runtime` chỉ copy phần kết quả thư viện sang môi trường sạch. Toàn bộ file cache tải về của pip, build tools trung gian và file tạm trong quá trình cài đặt đều bị bỏ lại ở stage builder và không bị đóng gói vào image thành phẩm.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> - Với Dockerfile tối ưu hiện tại: Các layer được dùng lại từ cache (CACHED) gồm: tải base image, tạo workdir, `COPY requirements.txt .`, `RUN pip install ...`, và tạo `appuser`. Layer phải chạy lại bắt đầu từ `COPY app ./app` (vì file mã nguồn trong thư mục `app/` thay đổi mã hash checksum), kéo theo các layer sau nó là `COPY utils ./utils`, `RUN chown ...` và đóng gói image. Thời gian build lại chỉ mất 1-2 giây.
> - Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi khi sửa dù chỉ một ký tự trong `app/main.py`, mã hash của toàn bộ context thư mục bị thay đổi, làm vô hiệu hóa cache từ layer `COPY . .`. Do đó, Docker bị ép phải chạy lại lệnh `RUN pip install` ngay phía sau, buộc container phải tải và cài đặt lại toàn bộ thư viện từ đầu, khiến thời gian build kéo dài hàng phút mỗi lần sửa code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện leo thang đặc quyền:
> 1. Ứng dụng Python có một lỗ hổng bảo mật (ví dụ: Command Injection, Remote Code Execution qua thư viện bên thứ ba hoặc Deserialization không an toàn).
> 2. Kẻ tấn công gửi payload khai thác thành công lỗ hổng và chiếm được quyền thực thi lệnh (mở một reverse shell) bên trong container.
> 3. Vì container chạy mặc định dưới quyền `root` (UID 0), kẻ tấn công trở thành root trong container: có toàn quyền sửa đổi file hệ thống, cài mã độc, truy cập network socket và nếu máy host có sơ hở (như mount Docker socket `/var/run/docker.sock`, cấp quyền `privileged`, hoặc lỗi bảo mật kernel container escape), kẻ tấn công sẽ thoát khỏi container và chiếm trọn quyền quản trị root trên máy chủ host.
> 
> Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay tại bước 3: Bằng việc chuyển sang một người dùng thường không có đặc quyền quản trị (non-root UID 10001), khi kẻ tấn công chiếm được quyền thực thi code, họ chỉ sở hữu quyền hạn tối thiểu của `appuser`. Họ không thể cài đặt phần mềm, không thể can thiệp vào các tài nguyên hệ thống nhạy cảm hay tương tác với kernel host, chặn đứng nguy cơ breakout và bảo vệ an toàn cho máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Một người dùng có thể gửi tối đa **20 request** trong 2 giây liên tiếp.
> 
> Cách đạt được con số đó:
> - Khi đếm theo phút đồng hồ cố định (Fixed Window), hệ thống reset bộ đếm về 0 vào mỗi đầu phút (giây thứ 00).
> - Kẻ tấn công canh thời gian và gửi dồn 10 request vào giây cuối cùng của phút thứ nhất (lúc 10:00:59). Cả 10 request này đều hợp lệ vì chưa vượt hạn mức của phút đó.
> - Ngay 1 giây sau, khi đồng hồ nhảy sang phút mới (lúc 10:01:00), bộ đếm được reset về 0. Kẻ tấn công lập tức gửi thêm 10 request nữa trong giây này. Vẫn được tính là "hợp lệ" vì thuộc hạn mức của phút mới.
> - Kết quả: Trong khoảng thời gian chỉ vỏn vẹn 2 giây (từ 10:00:59 đến 10:01:00), có tổng cộng 20 request được gửi thành công tới hệ thống, làm tăng đột biến tải gấp đôi cho server và backend LLM. Thuật toán cửa sổ trượt (Sliding Window) loại bỏ hoàn toàn kẽ hở này vì nó luôn xét đúng khoảng thời gian 60 giây liên tục tính từ thời điểm hiện tại trở về trước.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Khác nhau:
> - **Rate Limit:** Giới hạn theo **vận tốc / tần suất gọi (số request trong một đơn vị thời gian)** nhằm ngăn chặn tấn công DoS, brute force và bảo vệ năng lực phục vụ đồng thời của web server.
> - **Cost Guard:** Giới hạn theo **ngân sách tài chính lũy kế (tổng số tiền USD trong tháng)** nhằm kiểm soát chi phí thực tế phát sinh từ số lượng token tiêu thụ khi gọi LLM.
> 
> Tình huống minh họa:
> 1. **Rate limit cho qua nhưng Cost guard chặn:** Người dùng chỉ gửi duy nhất 1 request trong vòng 15 phút (tần suất cực kỳ thưa, hoàn toàn thỏa mãn rate limit 10 request/phút). Tuy nhiên, request này gửi kèm một tài liệu khổng lồ 100.000 token khiến chi phí ước tính vượt quá hạn mức $10/tháng còn lại của tài khoản -> Cost guard chặn lại với mã lỗi 402 Payment Required.
> 2. **Cost guard cho qua nhưng Rate limit chặn:** Người dùng mới bắt đầu chu kỳ tháng và còn nguyên $10 ngân sách. User viết script gửi dồn dập 15 request "hello" chỉ tốn vài token (tổng chi phí chưa tới $0.0001, ngân sách còn rất nhiều) trong vòng 5 giây -> Rate limiter lập tức phát hiện tần suất vượt quá 10 req/phút và chặn từ request thứ 11 với mã 429 Too Many Requests.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện xảy ra thảm họa:
> 1. Redis gặp sự cố gián đoạn kết nối mạng hoặc quá tải trong vòng 30 giây.
> 2. Bộ kiểm tra sức khỏe của Orchestrator (Docker Swarm/Kubernetes/Cloud) gửi liveness probe định kỳ vào endpoint gộp của cả 3 container agent. Do endpoint này kiểm tra Redis và Redis không phản hồi, cả 3 container đều đồng loạt trả về lỗi (503 hoặc timeout).
> 3. Orchestrator hiểu nhầm rằng tiến trình của các container ứng dụng đã bị treo (deadlock/unresponsive), do đó tự động kích hoạt lệnh **Restart (tiêu diệt và khởi động lại) toàn bộ cả 3 container**.
> 4. Trong lúc cả 3 container đang bị tắt và reboot lại, không còn bất kỳ instance nào hoạt động để phục vụ người dùng. Tất cả các request của khách hàng gửi tới hệ thống đều nhận về lỗi `502 Bad Gateway` (sập toàn bộ hệ thống).
> 5. Khi Redis phục hồi sau 30 giây, các container vẫn đang chật vật trong chu kỳ khởi động lại (restart loop) hoặc mất thêm thời gian để warm up.
> => Sự cố tạm thời của Redis (vốn chỉ cần tạm ngừng nhận request mới bằng `/ready`) đã biến thành sự cố sập hoàn toàn hệ thống và gây gián đoạn dịch vụ nghiêm trọng.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Nếu lưu lịch sử trong dict Python trong RAM của từng container:
> - Do 3 container đứng sau Load Balancer, các request liên tiếp của cùng một `X-User-Id` sẽ được bộ cân bằng tải phân phối xoay vòng ngẫu nhiên sang các container khác nhau (container 1, container 2, hoặc container 3).
> - Mỗi container có một vùng nhớ RAM tách biệt hoàn toàn. Do đó, người dùng sẽ thấy giá trị `history_length` **thay đổi lộn xộn, nhảy cóc thất thường hoặc đột ngột quay trở về 0** (ví dụ: lượt 1 vào container A -> length=0, lượt 2 vào container B -> length=0 vì B chưa nhận tin nhắn nào, lượt 3 vào container C -> length=0, lượt 4 quay lại A -> length=2).
> - Hậu quả là AI agent liên tục bị "mất trí nhớ", không thể nắm bắt được ngữ cảnh các câu hỏi trước đó. Ngược lại, khi lưu state ở Redis tập trung, mọi container cùng đọc/ghi vào một nguồn chung, giúp `history_length` tăng đều đặn (0 -> 2 -> 4 -> 6 -> ...) bất kể request rơi vào container nào.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> - **Thông báo lỗi:** Khi deploy Web Service lên Render thành công, gọi endpoint `/health` trả về 200 OK nhưng gọi `/ready` lại trả về mã lỗi HTTP `503 {"status": "not ready", "redis": false}`.
> - **Cách tìm ra nguyên nhân:** Dựa vào mã nguồn của `ready()` trong `app/main.py`, endpoint này trả về `"redis": false` khi kết nối tới Redis thất bại (`store.ping()` trả về `False`). Kiểm tra log trên Render dashboard và mục Environment Variables của Web Service, phát hiện ra biến `REDIS_URL` chưa được gán nên ứng dụng tự động lấy giá trị mặc định `redis://localhost:6379/0`. Trong môi trường container riêng biệt trên Render, `localhost` không có Redis nào đang chạy.
> - **Cách sửa:** Tôi đã tạo một dịch vụ **Key Value / Redis** (`day12-redis`) trên Render, copy đường dẫn **Internal Connection String** (dạng `redis://red-xxxxxxxx:6379`), sau đó quay lại Web Service -> tab **Environment** -> thêm biến `REDIS_URL` với giá trị vừa copy và lưu lại. Khi Render tự động redeploy, endpoint `/ready` đã kết nối thông suốt tới Redis và trả về mã `200 {"status": "ready", "redis": true}`.
