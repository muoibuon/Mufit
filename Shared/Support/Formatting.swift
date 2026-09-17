import Foundation
import SwiftUI

enum Fmt {
    static func kcal(_ v: Double) -> String { "\(Int(v.rounded())) kcal" }
    static func grams(_ v: Double) -> String { "\(Int(v.rounded())) gram" }
    static func kg(_ v: Double) -> String { String(format: "%.1f kg", v) }
    static func percent(_ v: Double) -> String { String(format: "%.1f%%", v) }
    static func ml(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1f L", v / 1000) : "\(Int(v)) ml"
    }
    static func int(_ v: Double) -> String { "\(Int(v.rounded()))" }

    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "d/M"
        return f
    }()

    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()

    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "EEEE"
        return f
    }()

    /// "Thứ Hai", "Chủ Nhật"… dùng cho nhãn lặp lại hàng tuần.
    static func weekdayName(_ date: Date) -> String {
        weekday.string(from: date)
    }

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}

// MARK: - Theme

/// Hai bảng màu: mặc định có màu, và bản tương phản cao.
///
/// Bản tương phản cao là nền đen tuyệt đối với chữ trắng tuyệt đối — tỉ lệ 21:1,
/// mức cao nhất thang WCAG đo được, và cao hơn nền trắng chữ đen về mặt cảm nhận
/// vì loại bỏ hẳn ánh sáng nền chói. Không dùng màu sắc: mức độ quan trọng được
/// thể hiện bằng *độ sáng* — việc cần chú ý nhất thì trắng nhất, việc đã ổn thì
/// xám và lùi về sau.
@MainActor
final class ThemeState: ObservableObject {
    static let shared = ThemeState()

    private static let storageKey = "highContrastTheme"

    @Published var isHighContrast: Bool {
        didSet { UserDefaults.standard.set(isHighContrast, forKey: Self.storageKey) }
    }

    private init() {
        // Mặc định bật tương phản cao; lần sau tôn trọng lựa chọn đã lưu.
        isHighContrast = UserDefaults.standard.object(forKey: Self.storageKey) as? Bool ?? true
    }

    /// Thang sáng trên nền đen: 1.0 = trắng tuyệt đối, 0 = đen tuyệt đối.
    private func ink(_ level: CGFloat) -> Color {
        Color(UIColor(white: level, alpha: 1))
    }

    var brand: Color { isHighContrast ? ink(1.0) : Color(red: 0.16, green: 0.55, blue: 0.98) }

    /// Màu chữ/biểu tượng đặt trên nền `brand`. Nền brand ở chế độ tương phản cao
    /// là trắng nên chữ phải là đen; ở bảng màu thường nền xanh nên chữ trắng.
    var onBrand: Color { isHighContrast ? ink(0) : .white }

    /// Cảnh báo nặng — đậm nhất, luôn đi kèm icon cảnh báo dạng đặc.
    var danger: Color { isHighContrast ? ink(1.0) : Color(red: 0.91, green: 0.30, blue: 0.34) }

    /// Cảnh báo vừa — xám trung tính, vẫn nổi nhưng không át cảnh báo nặng.
    var warning: Color { isHighContrast ? ink(0.62) : Color(red: 0.99, green: 0.55, blue: 0.20) }

    /// Trạng thái tốt — nhạt, lùi về sau vì không cần người dùng xử lý.
    var positive: Color { isHighContrast ? ink(0.42) : Color(red: 0.18, green: 0.72, blue: 0.47) }

    /// Nền màn hình: trắng/đen tuyệt đối ở chế độ tương phản cao.
    var background: Color {
        isHighContrast ? ink(0) : Color(.systemGroupedBackground)
    }

    /// Nền thẻ nội dung: xám đậm nổi trên nền đen, không cần viền để phân tách —
    /// cùng cách app Sức khoẻ của iOS dựng thẻ.
    var card: Color {
        isHighContrast ? ink(0.11) : Color(.secondarySystemGroupedBackground)
    }

    /// Nền cho ô lồng bên trong thẻ; sáng hơn một bậc để tách khỏi nền thẻ.
    var cardElevated: Color {
        isHighContrast ? ink(0.19) : Color(.tertiarySystemGroupedBackground)
    }

    /// Không còn dùng viền để phân tách module; giữ lại để nơi gọi khỏi phải sửa.
    var cardBorder: Color { .clear }

    var cardBorderWidth: CGFloat { 0 }

    /// Nền mờ cho chip và thanh tiến độ. Ở chế độ tương phản cao dùng xám đặc
    /// thay vì màu pha alpha, để mép luôn sắc nét trên nền đen.
    func muted(_ color: Color) -> Color {
        isHighContrast ? ink(0.26) : color.opacity(0.16)
    }

    /// Bắt buộc giao diện tối khi bật tương phản cao, để `.primary` / `.secondary`
    /// của hệ thống cũng chuyển sang thang trắng cho khớp với nền đen.
    var forcedColorScheme: ColorScheme? { isHighContrast ? .dark : nil }
}

/// Màu cảnh báo vượt ngưỡng. Giữ đỏ thật kể cả ở theme trắng đen: ăn vượt ngưỡng
/// là thứ phải nhận ra ngay từ khoé mắt, không nên để lẫn vào thang xám.
enum AlertPalette {
    static let over = Color(red: 1.00, green: 0.21, blue: 0.17)
    static let overBright = Color(red: 1.00, green: 0.45, blue: 0.38)
}

/// Màu cho các icon chính. Giữ màu thật kể cả ở theme trắng đen — icon có màu giúp
/// nhận ra ngay module đang xem, giống cách app Sức khoẻ tô màu từng nhóm chỉ số.
/// Chữ và số vẫn theo thang trắng đen nên độ tương phản đọc không bị ảnh hưởng.
enum IconPalette {
    static let energy   = Color(red: 1.00, green: 0.45, blue: 0.10)  // cam — calo
    static let protein  = Color(red: 0.96, green: 0.30, blue: 0.52)  // hồng — đạm
    static let carb     = Color(red: 0.99, green: 0.76, blue: 0.16)  // vàng — carb
    static let fat      = Color(red: 0.24, green: 0.80, blue: 0.66)  // xanh ngọc — béo
    static let water    = Color(red: 0.24, green: 0.62, blue: 0.99)  // xanh dương — nước
    static let body     = Color(red: 0.66, green: 0.50, blue: 0.98)  // tím — cơ thể
    static let training = Color(red: 0.32, green: 0.83, blue: 0.45)  // xanh lá — tập luyện
    static let heart    = Color(red: 0.98, green: 0.31, blue: 0.35)  // đỏ — sức khoẻ
    static let sun      = Color(red: 1.00, green: 0.81, blue: 0.22)  // vàng nắng
    static let sleep    = Color(red: 0.45, green: 0.55, blue: 0.95)  // chàm — nghỉ ngơi
    static let insight  = Color(red: 0.40, green: 0.72, blue: 1.00)  // xanh nhạt — phân tích
    static let neutral  = Color(red: 0.60, green: 0.64, blue: 0.70)  // xám xanh — trung tính

    private static let map: [String: Color] = [
        // Năng lượng
        "flame.fill": energy, "flame.circle.fill": energy,
        // Dinh dưỡng
        "fish.fill": protein, "bolt.fill": carb, "oilcan.fill": fat,
        "fork.knife": energy, "chart.pie.fill": carb,
        "takeoutbag.and.cup.and.straw": energy, "exclamationmark.bubble.fill": carb,
        "pills.fill": protein, "pills": protein,
        // Nước và nắng
        "drop.fill": water, "humidity.fill": water,
        "sun.max.fill": sun, "sun.horizon.fill": sun,
        "sun.max.trianglebadge.exclamationmark": sun,
        // Cơ thể
        "figure.stand": body, "figure.arms.open": body, "scalemass": body,
        "ruler": fat, "drop.triangle": energy, "circle.hexagongrid.fill": energy,
        "clock.arrow.circlepath": neutral,
        // Tập luyện
        "dumbbell.fill": training, "figure.strengthtraining.traditional": training,
        "figure.walk.motion": training, "play.fill": training,
        "repeat": training, "square.stack.3d.up": training,
        "checkmark.circle": training, "checkmark.circle.fill": training,
        "checkmark.seal.fill": training, "target": training,
        "list.bullet": neutral, "list.bullet.rectangle": neutral,
        // Lịch
        "calendar": insight, "calendar.day.timeline.left": insight,
        // Phân tích
        "chart.bar.fill": insight, "chart.bar.xaxis": insight,
        "chart.line.uptrend.xyaxis": insight, "chart.xyaxis.line": insight,
        "speedometer": insight, "book.closed.fill": neutral,
        // Sức khoẻ
        "cross.case.fill": heart, "cross.case": heart, "heart.text.square": heart,
        "heart.fill": heart, "bed.double.fill": sleep,
        "lightbulb.fill": sun,
        // Thời tiết theo mùa
        "thermometer.sun.fill": energy, "cloud.sun.fill": insight,
        "wind": water, "thermometer.snowflake": water,
        // Nhóm cơ
        "figure.core.training": training,
        // Bữa ăn
        "sunrise.fill": sun, "moon.stars.fill": sleep,
        "carrot.fill": fat, "arrow.clockwise.heart.fill": heart,
    ]

    static func color(for systemImage: String) -> Color {
        map[systemImage] ?? neutral
    }
}

@MainActor
extension Color {
    static var brand: Color { ThemeState.shared.brand }
    static var brandRed: Color { ThemeState.shared.danger }
    static var brandWarm: Color { ThemeState.shared.warning }
    static var brandGreen: Color { ThemeState.shared.positive }
    static var appBackground: Color { ThemeState.shared.background }
    static var appCard: Color { ThemeState.shared.card }
    static var appCardElevated: Color { ThemeState.shared.cardElevated }
    static var appBorder: Color { ThemeState.shared.cardBorder }
    static var onBrand: Color { ThemeState.shared.onBrand }

    /// Nền nhạt cho chip / track, tôn trọng chế độ tương phản cao.
    func mutedFill() -> Color { ThemeState.shared.muted(self) }
}


// MARK: - Thang chữ

extension Font {
    /// Tiêu đề thẻ.
    static var cardTitle: Font { .system(.headline, design: .default).weight(.bold) }

    /// Con số chính của một thẻ.
    static func metric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default).monospacedDigit()
    }

    /// Đơn vị đi kèm con số chính.
    static var unitLabel: Font { .system(.subheadline, design: .default).weight(.semibold) }

    /// Nhãn phụ dưới con số.
    static var tileCaption: Font { .system(.caption, design: .default).weight(.medium) }
}
