# Bản đồ giải phẫu Mufit

Mở **Cơ thể → Bản đồ cơ tuần này**. Chọn Nam/Nữ, Trước/Sau và lớp Nông/Trung gian/Sâu.
Nút **Phóng to & tra cứu tên cơ** mở mô hình lớn và danh mục tìm theo tên Việt/Latin.
Chạm một cấu trúc để xem vị trí, thống kê, tài liệu nguồn và ghi chú riêng.

Danh mục gồm 56 cấu trúc chọn lọc: cơ riêng lẻ, ba bó delta và các nhóm như dựng sống,
thắt lưng–chậu. Đây là sơ đồ giáo dục tự vẽ, chưa phải atlas đầy đủ toàn thân hoặc
mô hình giải phẫu được thẩm định lâm sàng. Các lớp trung gian/sâu là cửa sổ bóc tách
theo từng vùng; không phải một mặt phẳng cắt chung. Hai bên dùng chung dữ liệu tập.

## Tài liệu

- [OpenStax Anatomy & Physiology 2e, 11.3: Đầu, cổ và lưng](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-3-axial-muscles-of-the-head-neck-and-back)
- [11.4: Thành bụng và ngực](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-4-axial-muscles-of-the-abdominal-wall-and-thorax)
- [11.5: Đai vai và chi trên](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-5-muscles-of-the-pectoral-girdle-and-upper-limbs)
- [11.6: Đai chậu và chi dưới](https://openstax.org/books/anatomy-and-physiology-2e/pages/11-6-appendicular-muscles-of-the-pelvic-girdle-and-lower-limbs)

Các nguồn trên hỗ trợ danh pháp, vị trí và phân lớp. Liên hệ giữa bài tập và từng cơ
trong app là ước tính cơ sinh học của phần mềm, không phải phép đo EMG hoặc khẳng định
mọi cơ được kích thích như nhau. Khuyến nghị tập luyện vẫn liên kết riêng tới ACSM,
CDC và nguồn theo bệnh nền trong màn chi tiết.

## Ghi nhận và lưu dữ liệu

- Xanh ✓: có hiệp đã thực hiện trong buổi hoàn thành, theo ánh xạ bài hoặc khai báo cơ cụ thể.
- Vàng: nhóm cũ có hoạt động nhưng không xác định được cấu trúc đó.
- Hồng: chưa có dữ liệu ánh xạ; không có nghĩa cơ chưa từng hoạt động.
- Tuần bắt đầu 00:00 thứ Hai theo múi giờ thiết bị. Không xóa lịch sử khi đổi tuần.
- Bài tự tạo/nhập ngoài không được tự suy ra mọi cơ từ nhãn nhóm chung.
- Trong thiết lập bài, mở **Cơ cụ thể**, tắt tự động rồi chọn cơ để khai báo mục tiêu cho bài đó.
  Lựa chọn lưu trong từng bài của buổi tập và được sao lưu cùng lịch sử.
- Ghi chú từng cấu trúc dùng khóa riêng; ghi chú nhóm từ bản cũ vẫn được giữ và hiển thị.

Ảnh minh họa (màu xanh là dữ liệu demo): [Nam](muscle-map-male.png), [Nữ](muscle-map-female.png).

## Kiểm tra

`bash Tests/run-muscle-tests.sh` kiểm tra đủ vùng chạm cho 56 cấu trúc, đường vẽ hợp lệ,
không suy ra cơ từ bài chưa biết, giữ trạng thái tuần, nâng cấp kho dữ liệu cũ,
lưu ghi chú độc lập và sao lưu/khôi phục lựa chọn cơ cụ thể.
