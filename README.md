# Mufit

Mufit là ứng dụng iOS theo dõi tập luyện, ăn uống và thay đổi cơ thể theo một hồ sơ cá nhân. Trọng tâm của dự án là trả lời những câu hỏi cụ thể hơn một nhật ký tập đơn thuần: **đã hoàn thành bao nhiêu hiệp, bài đó ưu tiên vùng cơ nào, vùng nào chỉ tham gia hỗ trợ, và kế hoạch ăn uống thay đổi thế nào theo mục tiêu cùng hoạt động thực tế?**

Ứng dụng hiện có giao diện tiếng Việt, lưu dữ liệu trên thiết bị bằng SwiftData và dùng được ở chế độ khách. Bản đồ cơ là sơ đồ giáo dục: màu sắc thể hiện dữ liệu buổi tập đã ghi, không đo trực tiếp mức kích hoạt hay khả năng hồi phục của cơ.

## Điểm khác biệt

**Chi tiết đến vùng cơ.** Bản đồ chọn lọc gồm 74 vùng và cấu trúc có thể tra cứu trên mô hình nam hoặc nữ, mặt trước hoặc sau, với ba lớp nông, trung gian và sâu. Ngực lớn có vùng trên, giữa và dưới; cơ thang có bó trên, giữa và dưới; cơ nhị đầu và tam đầu có các đầu riêng. Một bài tập được ghi theo vùng ưu tiên và vùng tham gia hỗ trợ. Chạm vào vùng cơ để xem số ngày, số buổi, hiệp chính, hiệp hỗ trợ, bài tập liên quan và ghi chú riêng. [Cách vẽ, giới hạn và nguồn giải phẫu](Docs/Anatomy.md).

**Tập trung vào dữ liệu tập đã thực hiện.** Người dùng tự dựng buổi theo lịch, đặt bài, số hiệp, reps, mức tạ, nghỉ giữa hiệp, superset và drop set. Khi tập, từng hiệp được đánh dấu với số reps thực tế. Tổng kết đối chiếu reps thực tế với kế hoạch, khối lượng nâng và năng lượng ước tính. Bản đồ tuần chỉ tô vùng cơ khi có hiệp hợp lệ trong buổi đã hoàn thành; nhãn nhóm cơ chung không bị suy diễn thành mọi cơ thành phần.

**Cá nhân hóa trên nhiều phần của cùng một hồ sơ.** Tuổi, giới tính sinh học, chiều cao, cân nặng, mức hoạt động, mục tiêu và số đo cơ thể tham gia tính nhu cầu năng lượng. Mục tiêu có thể gồm giảm mỡ, tăng cơ, sức mạnh, sức bền hoặc sức khỏe; mức điều chỉnh calo có thể sửa thủ công. Lịch tập, lượng ăn, nước, số đo, thời tiết và bệnh nền được trình bày trong cùng dòng theo dõi. Gợi ý theo bệnh nền có dẫn nguồn và nêu rõ giới hạn của dữ liệu người dùng cung cấp.

## Tính năng hiện có

- **Lịch và buổi tập:** tạo buổi theo ngày, lặp hằng tuần, chọn từ 146 bài tập đi kèm hoặc tự tạo bài; có thể tải thêm bài từ wger. Thiết lập hiệp thường, khởi động, AMRAP, drop set và superset; ghi reps thực tế, mức tạ, thời gian nghỉ và ghi chú.
- **Bản đồ cơ:** tra cứu tên Việt/Latin, phóng to mô hình, chọn lớp giải phẫu, xem trạng thái tuần và lưu ghi chú cho từng vùng. Ánh xạ tự động theo bài tập có thể được thay bằng lựa chọn cơ cụ thể cho từng bài trong buổi.
- **Ăn uống và năng lượng:** nhật ký bữa ăn theo khẩu phần, 138 món đi kèm và món tự tạo; theo dõi calo, protein, carb và chất béo. Mục tiêu ngày tính từ hồ sơ, số đo và buổi tập, kèm phần giải thích các thành phần phép tính.
- **Nước và môi trường:** theo dõi nước uống, thời tiết/UV khi có dữ liệu vị trí, ghi nhận phơi nắng và thông tin vitamin D mang tính tham khảo. Widget hiển thị nhanh dinh dưỡng và nước.
- **Cơ thể và phân tích:** lưu cân nặng, vòng eo và các số đo thành phần cơ thể nếu có; xem xu hướng, khối lượng tập theo nhóm cơ, hiệu suất buổi tập và cân bằng năng lượng trong 7, 14 hoặc 30 ngày.
- **Hồ sơ và dữ liệu:** chỉnh mục tiêu, bệnh nền và giao diện tương phản cao. Dữ liệu mặc định ở trên máy; đăng nhập và sao lưu Firebase/Firestore chỉ khả dụng khi người triển khai cấu hình dịch vụ. Sao lưu đám mây là bản ghi đè, không phải đồng bộ hợp nhất hai chiều.

## Mufit khác gì so với các ứng dụng cùng nhóm?

[Hevy](https://www.hevyapp.com/features/muscle-group-workout-chart/) có nhật ký tập, sơ đồ cơ thể và thống kê số hiệp **theo nhóm cơ**. [Fitbod](https://help.fitbod.me/hc/en-us/articles/360004429814-How-Fitbod-Creates-Your-Workout) tạo bài tập cá nhân hóa theo mục tiêu, thiết bị, lịch sử và trạng thái hồi phục; ứng dụng này cũng có [bản đồ tác động cơ](https://help.fitbod.me/hc/en-us/articles/360006269014-Muscle-Recovery). Mufit chọn một trọng tâm khác: theo dõi **các vùng/đầu cơ được chọn lọc trong chính nhật ký tuần**, tách hiệp chính và hiệp hỗ trợ, cho phép sửa mục tiêu cơ ở từng bài, rồi đặt dữ liệu đó cạnh dinh dưỡng, số đo và ghi chú cá nhân.

Đây là so sánh về **trọng tâm trình bày và độ hạt của bản đồ cơ trong phiên bản hiện tại**, không phải khẳng định Mufit có nhiều bài tập hơn, tự động hóa tốt hơn hoặc đo kích hoạt cơ chính xác hơn các ứng dụng trên. Bản đồ của Mufit không bao phủ toàn bộ hệ cơ; bài tự tạo hoặc nhập ngoài không được tự gán chi tiết nếu thiếu ánh xạ đáng tin cậy.

## Bắt đầu

Yêu cầu: macOS có Xcode, iOS 18 trở lên để chạy ứng dụng hoặc iOS Simulator. Mở `Mufit.xcodeproj`, chọn scheme `Mufit` và thiết bị đích, rồi Build/Run. Có thể kiểm tra bản build simulator bằng lệnh:

```sh
xcodebuild -project Mufit.xcodeproj -scheme Mufit -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Ứng dụng có chế độ **Dùng thử không cần tài khoản**. Để triển khai đăng nhập và sao lưu đám mây, cấu hình dịch vụ trong `Shared/Services/FirebaseConfig.swift` và `Shared/Services/AuthConfig.swift`; không đưa khóa hoặc thông tin riêng vào commit công khai. Nếu chưa cấu hình, dữ liệu tập và ăn uống vẫn được lưu trên thiết bị.

Kiểm tra phần bản đồ cơ và khả năng đọc dữ liệu cũ:

```sh
bash Tests/run-muscle-tests.sh
```

## Giới hạn và nguồn

Liên hệ bài tập–vùng cơ là **ước tính theo loại bài**, không phải phép đo EMG của người tập; một bó cơ không hoạt động độc lập hoàn toàn. Năng lượng tiêu hao, nhu cầu dinh dưỡng và hướng dẫn theo bệnh nền cũng là thông tin tham khảo, không thay thế chuyên gia y tế. Tài liệu giải phẫu và các nghiên cứu về góc ghế, cơ thang, nhị đầu, tam đầu được ghi trong [Docs/Anatomy.md](Docs/Anatomy.md). Những tính năng được mô tả ở đây phản ánh mã nguồn hiện tại; việc dùng dịch vụ trực tuyến phụ thuộc cấu hình và kết nối mạng.
