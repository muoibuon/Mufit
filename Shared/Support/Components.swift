import SwiftUI

/// Giữ màu chữ và nền của nút chính thành một cặp rõ ràng ở cả hai theme.
/// `.borderedProminent` tự chọn chữ trắng khi tint chuyển thành trắng ở
/// chế độ tương phản cao, khiến nhãn biến mất.
struct ProminentActionStyle: ButtonStyle {
    var background: Color = .brand
    var foreground: Color = .onBrand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(background, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Thẻ nội dung dùng chung toàn app.
struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    var iconColor: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label {
                    Text(title).font(.cardTitle)
                } icon: {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(iconColor ?? IconPalette.color(for: systemImage))
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Thẻ ở rìa màn hình lùi lại một chút, thẻ đang đọc thì nổi lên.
        // Không cần state nào — SwiftUI tự tính theo vị trí cuộn.
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.45)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
    }
}

/// Vòng tiến độ cho calo / macro.
///
/// Khi vượt mục tiêu, cả vòng chuyển đỏ chứ không chỉ riêng phần dôi ra — nhìn
/// thoáng qua phải thấy ngay là "đã quá", không phải ngồi đọc tỉ lệ cung tròn.
/// Phần vượt được vẽ đè bằng đỏ sáng hơn để vẫn biết vượt bao nhiêu.
/// Màu đỏ đặc là đủ để cảnh báo; không dùng hiệu ứng phát sáng.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = .brand

    private var isOver: Bool { progress > 1 }
    private var overflow: Double { min(max(progress - 1, 0), 1) }

    var body: some View {
        ZStack {
            if isOver {
                // Toàn vòng đỏ.
                Circle()
                    .stroke(AlertPalette.over, lineWidth: lineWidth)
                // Phần vượt ngưỡng, đỏ sáng hơn.
                Circle()
                    .trim(from: 0, to: overflow)
                    .stroke(AlertPalette.overBright, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .stroke(tint.mutedFill(), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        // Spring cho cảm giác có quán tính: vòng vọt tới rồi lắc nhẹ về đúng chỗ.
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: progress)
    }
}

/// Thanh macro nằm ngang có nhãn.
///
/// Khi lượng nạp vượt ngưỡng, thanh chuyển đỏ đặc kèm icon cảnh báo — đủ để nhận
/// ra ngay khi liếc qua, không cần hiệu ứng phát sáng.
struct MacroBar: View {
    var label: String
    var consumed: Double
    var target: Double
    var unit: String
    var tint: Color
    /// Vượt bao nhiêu lần mục tiêu thì coi là quá ngưỡng.
    var overThreshold: Double = 1.15
    /// Đặt giá trị này để dùng mức vượt **tuyệt đối** thay cho tỉ lệ. Hợp với những
    /// chỉ số mà vượt một chút không có ý nghĩa gì, ví dụ lượng nước uống.
    var overAllowance: Double? = nil

    private var ratio: Double { target > 0 ? consumed / target : 0 }

    private var isOver: Bool {
        if let overAllowance { return consumed - target > overAllowance }
        return ratio > overThreshold
    }
    private var overBy: Double { max(0, consumed - target) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(AlertPalette.over)
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOver ? AlertPalette.over : .primary)
                Spacer()
                Text("\(Int(consumed)) / \(Int(target)) \(unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isOver ? AlertPalette.over : .secondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(isOver ? AlertPalette.over.opacity(0.22) : tint.mutedFill())

                    Capsule()
                        .fill(isOver
                              ? LinearGradient(
                                    colors: [AlertPalette.over, AlertPalette.overBright],
                                    startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [tint, tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(ratio, 1))
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: ratio)

            if isOver {
                Text("Vượt \(Int(overBy)) \(unit) so với mục tiêu")
                    .font(.caption2)
                    .foregroundStyle(AlertPalette.over)
            }
        }
    }
}

/// Ô thống kê nhỏ.
///
/// Đơn vị tách riêng khỏi con số: nếu nhét cả đơn vị vào chuỗi giá trị thì ô nào
/// chuỗi dài hơn sẽ bị thu nhỏ chữ, khiến các ô cùng hàng trông lệch cỡ font.
struct StatTile: View {
    var value: String
    var unit: String? = nil
    var caption: String
    var systemImage: String
    /// Bỏ trống thì lấy màu theo tên icon.
    var tint: Color? = nil

    private var iconColor: Color { tint ?? IconPalette.color(for: systemImage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                // Cỡ và độ đậm cố định để icon các ô có cùng trọng lượng thị giác,
                // khe cao cố định để phần chữ bên dưới không bị nhích lên xuống.
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(height: 22, alignment: .center)
                .symbolEffect(.bounce, value: value)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.metric(21))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    // Từng chữ số trượt như đồng hồ xăng thay vì nhảy phắt.
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                if let unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(caption)
                .font(.tileCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Color.appCardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Nhãn nhỏ cho kiểu set.
struct SetTypeBadge: View {
    var type: SetType

    private var tint: Color {
        switch type {
        case .normal: return .secondary
        case .dropSet: return .brandWarm
        case .superSet: return .brand
        case .warmup: return .brandGreen
        case .amrap: return .brandRed
        }
    }

    var body: some View {
        Text(type.shortLabel)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.mutedFill(), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
