# Bản đồ giải phẫu Mufit

Mở **Cơ thể → Bản đồ cơ tuần này**. Chọn Nam/Nữ, Trước/Sau và lớp Nông/Trung gian/Sâu.
Nút **Phóng to & tra cứu tên cơ** mở mô hình lớn và danh mục tìm theo tên Việt/Latin.
Chạm một cấu trúc để xem vùng đó phóng to bên cạnh hình toàn thân, thống kê,
tài liệu nguồn và ghi chú riêng.

Danh mục gồm 74 vùng/cấu trúc chọn lọc: cơ ngực lớn được chia vùng trên (đòn), giữa
(ức–sườn) và dưới (sườn thấp); cơ thang chia bó trên/giữa/dưới; cơ nhị đầu cánh tay
chia đầu dài/ngắn; cơ tam đầu chia đầu dài/ngoài/trong. Đây là **các phần của cùng một
cơ**, không phải 11 cơ riêng. Ba bó delta, các cơ tứ đầu đùi và gân kheo cũng được
chọn riêng như trước. Các lớp sâu bổ sung cơ dưới đòn, cơ vùng thắt lưng, khoeo
và các bó cẳng chân. Nét vẽ dùng ánh sáng, thớ cơ và mốc bề mặt để dễ phân biệt
các cấu trúc; đây vẫn là sơ đồ giáo dục tự vẽ, chưa phải atlas đầy đủ toàn thân hoặc
mô hình giải phẫu được thẩm định lâm sàng. Các lớp trung gian/sâu là cửa sổ bóc tách
theo từng vùng; phần cơ mờ là lớp phía trên được giữ để định hướng, không phải một
mặt phẳng cắt chung. Hai bên dùng chung dữ liệu tập.

## Tài liệu

- [OpenStax Anatomy & Physiology 2e, 11.3: Đầu, cổ và lưng](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-3-axial-muscles-of-the-head-neck-and-back)
- [11.4: Thành bụng và ngực](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-4-axial-muscles-of-the-abdominal-wall-and-thorax)
- [11.5: Đai vai và chi trên](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-5-muscles-of-the-pectoral-girdle-and-upper-limbs)
- [11.6: Đai chậu và chi dưới](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-6-appendicular-muscles-of-the-pelvic-girdle-and-lower-limbs)

Các nguồn trên hỗ trợ danh pháp, vị trí và phân lớp. Dữ liệu về khác biệt vùng theo
bài tập tham khảo [ngực lớn ở năm góc ghế](https://pubmed.ncbi.nlm.nih.gov/33049982/),
[ngực lớn với ghế ngang/nghiêng](https://pubmed.ncbi.nlm.nih.gov/34644424/),
[ba bó cơ thang trong mười bài](https://pubmed.ncbi.nlm.nih.gov/12774999/),
[cơ nhị đầu và vị trí vai khi curl](https://pubmed.ncbi.nlm.nih.gov/24150552/),
và [ba đầu cơ tam đầu khi duỗi tay qua đầu](https://pubmed.ncbi.nlm.nih.gov/35819335/).
Các nghiên cứu này không chứng minh một bài chỉ tập một phần duy nhất. Chẳng hạn,
biến thể curl thường được gắn cho cả hai đầu nhị đầu vì chưa đủ căn cứ để gán riêng
theo tên bài. Dạng cable crossover không ghi góc kéo nên ưu tiên vùng giữa một cách
bảo thủ. `Ưu tiên` và `tham gia` là ước tính theo tên biến thể, không phải số đo EMG
cho người dùng hoặc khẳng định mức phát triển cơ. Khuyến nghị tập luyện vẫn liên kết riêng tới ACSM,
CDC và nguồn theo bệnh nền trong màn chi tiết.

## Ghi nhận và lưu dữ liệu

- Xanh: có hiệp đã thực hiện trong buổi hoàn thành, theo ánh xạ bài hoặc khai báo cơ cụ thể.
- Vàng: nhóm cũ có hoạt động nhưng không xác định được cấu trúc đó.
- Hồng: chưa có dữ liệu ánh xạ; không có nghĩa cơ chưa từng hoạt động.
- Tuần bắt đầu 00:00 thứ Hai theo múi giờ thiết bị. Không xóa lịch sử khi đổi tuần.
- Bài tự tạo/nhập ngoài không được tự suy ra mọi cơ từ nhãn nhóm chung.
- Các ID toàn cơ cũ (`pectoralisMajor`, `trapezius`, `bicepsBrachii`, `tricepsBrachii`)
  vẫn đọc được trong buổi tập và ghi chú cũ, nhưng không tự suy đoán hiệp nào thuộc
  bó/vùng mới. Ánh xạ tự động từ bài seed được tính lại theo biến thể của bài.
- Trong thiết lập bài, mở **Cơ cụ thể**, tắt tự động rồi chọn cơ để khai báo mục tiêu cho bài đó.
  Lựa chọn lưu trong từng bài của buổi tập và được sao lưu cùng lịch sử.
- Ghi chú từng cấu trúc dùng khóa riêng; ghi chú nhóm từ bản cũ vẫn được giữ và hiển thị.

Ảnh minh họa sáu góc nhìn: [Nam](muscle-map-male.png), [Nữ](muscle-map-female.png).

## Kiểm tra

`bash Tests/run-muscle-tests.sh` kiểm tra đủ vùng chạm cho 74 cấu trúc, đường vẽ hợp lệ,
không suy ra cơ từ bài chưa biết, giữ trạng thái tuần, nâng cấp kho dữ liệu cũ,
lưu ghi chú độc lập và sao lưu/khôi phục lựa chọn cơ cụ thể.
