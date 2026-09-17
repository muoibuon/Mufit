import WidgetKit
import SwiftUI

@main
struct MufitWidgets: WidgetBundle {
    var body: some Widget {
        NutritionWidget()
        HydrationWidget()
    }
}

/// Màu dùng riêng cho widget. Không lấy từ ThemeState vì widget chạy ở tiến trình
/// khác và phải đọc được trên mọi hình nền — nên bám vào màu hệ thống là an toàn nhất.
enum WidgetPalette {
    static let ink = Color.primary
    static let faint = Color.secondary
    static let over = AlertPalette.over
    static let overBright = AlertPalette.overBright
}

/// Thanh tiến độ ngang dùng chung cho cả hai widget.
struct WidgetBar: View {
    var progress: Double
    var height: CGFloat = 8
    var isOver: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(isOver ? WidgetPalette.over.opacity(0.25) : WidgetPalette.ink.opacity(0.18))
                Capsule()
                    .fill(isOver
                          ? LinearGradient(colors: [WidgetPalette.over, WidgetPalette.overBright],
                                           startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [WidgetPalette.ink, WidgetPalette.ink],
                                           startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// Vòng tiến độ thu nhỏ cho widget. Vượt ngưỡng thì đỏ toàn vòng, giống trong app.
struct WidgetRing: View {
    var progress: Double
    var lineWidth: CGFloat = 9

    private var isOver: Bool { progress > 1 }

    var body: some View {
        ZStack {
            if isOver {
                Circle().stroke(WidgetPalette.over, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(progress - 1, 1))
                    .stroke(WidgetPalette.overBright, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle().stroke(WidgetPalette.ink.opacity(0.18), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(WidgetPalette.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}
