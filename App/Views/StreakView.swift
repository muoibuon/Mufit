import SwiftUI

enum FirePalette {
    /// Streak giữ màu lửa thật ngay cả ở theme trắng đen — nó là điểm nhấn cảm xúc
    /// duy nhất của app, và chính màu lửa là thứ báo trạng thái "đang cháy".
    static let tip = Color(red: 1.00, green: 0.88, blue: 0.42)      // vàng sáng ở ngọn
    static let mid = Color(red: 1.00, green: 0.52, blue: 0.05)      // cam giữa thân
    static let base = Color(red: 0.88, green: 0.16, blue: 0.05)     // đỏ ở chân lửa
    static let ember = Color(red: 1.00, green: 0.70, blue: 0.20)
}

/// Con số streak được tô bằng dải màu lửa trôi liên tục từ dưới lên,
/// nên nhìn như ngọn lửa đang liếm qua chữ số. Chưa thắp thì chỉ là số xám phẳng.
struct FireNumber: View {
    /// Người bật "Giảm chuyển động" trong Trợ năng thường thấy khó chịu thật sự với
    /// hiệu ứng chạy vô tận — có người bị chóng mặt. Với họ, lửa vẫn có màu nhưng đứng yên.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var value: Int
    var isLit: Bool
    var size: CGFloat = 64

    /// Một chu kỳ màu: đỏ → cam → vàng → cam → đỏ. Điểm đầu trùng điểm cuối nên
    /// nối hai chu kỳ lại được một dải tuần hoàn liền mạch.
    private static let period: [Color] = [
        FirePalette.base, FirePalette.mid, FirePalette.tip, FirePalette.mid
    ]

    /// Hai chu kỳ, chốt lại bằng đúng màu mở đầu — 9 mốc, 8 đoạn đều nhau.
    private var stops: [Color] {
        Self.period + Self.period + [Self.period[0]]
    }

    private var numberText: some View {
        Text("\(value)")
            .font(.system(size: size, weight: .heavy, design: .default).monospacedDigit())
    }

    var body: some View {
        if isLit && !reduceMotion {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                numberText
                    .overlay { movingGradient(phase: t) }
                    .mask { numberText }
            }
        } else if isLit {
            // Vẫn là dải màu lửa, chỉ không trôi.
            numberText
                .overlay { movingGradient(phase: 0) }
                .mask { numberText }
        } else {
            numberText.foregroundStyle(.secondary)
        }
    }

    /// Dải cao gấp đôi chữ số và chứa đúng hai chu kỳ màu, nên bước sóng bằng đúng
    /// chiều cao chữ. Cho dải trượt đúng một bước sóng mỗi vòng thì khung cuối trùng
    /// khít khung đầu — vòng lặp không có mối nối, và tốc độ chuyển màu đều tuyệt đối.
    private func movingGradient(phase: Double) -> some View {
        GeometryReader { geo in
            let wavelength = geo.size.height
            let shift = CGFloat((phase / 2.4).truncatingRemainder(dividingBy: 1)) * wavelength

            LinearGradient(colors: stops, startPoint: .bottom, endPoint: .top)
                .frame(height: wavelength * 2)
                .offset(y: -wavelength + shift)
        }
    }
}

/// Thẻ streak trên màn hình Hôm nay.
struct StreakCard: View {
    let result: StreakCalculator.Result

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            FireNumber(value: result.current, isLit: result.isLitToday, size: 64)
                .frame(minWidth: 56)
                .contentTransition(.numericText(value: Double(result.current)))
                .animation(.snappy, value: result.current)

            VStack(alignment: .leading, spacing: 5) {
                Text("ngày liên tiếp")
                    .font(.subheadline.weight(.semibold))

                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if result.hasPlanToday && !result.isLitToday {
                    ProgressView(value: min(result.todayProgress, 1))
                        .tint(FirePalette.mid)
                        .padding(.top, 2)
                }

                if result.best > result.current && result.best > 0 {
                    Text("Kỷ lục: \(result.best) ngày")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Thắp được lửa là khoảnh khắc đáng ăn mừng — báo bằng rung nhẹ.
        .sensoryFeedback(.success, trigger: result.isLitToday)
    }
}
