import SwiftUI

/// Logo Google dựng từ đúng đường dẫn vector của nhãn hiệu (viewBox 48×48),
/// nên hình khớp bản chính thức thay vì vẽ gần đúng bằng cung tròn.
struct GoogleLogo: View {
    var size: CGFloat = 22

    private let blue = Color(red: 0.259, green: 0.522, blue: 0.957)   // #4285F4
    private let green = Color(red: 0.204, green: 0.659, blue: 0.325)  // #34A853
    private let yellow = Color(red: 0.984, green: 0.737, blue: 0.020) // #FBBC05
    private let red = Color(red: 0.918, green: 0.263, blue: 0.208)    // #EA4335

    var body: some View {
        Canvas { ctx, canvas in
            let scale = min(canvas.width, canvas.height) / 48
            let pt: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: x * scale, y: y * scale)
            }
            ctx.fill(bluePath(pt), with: .color(blue))
            ctx.fill(greenPath(pt), with: .color(green))
            ctx.fill(yellowPath(pt), with: .color(yellow))
            ctx.fill(redPath(pt), with: .color(red))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func bluePath(_ pt: (CGFloat, CGFloat) -> CGPoint) -> Path {
        var p = Path()
            p.move(to: pt(45.12, 24.50))
            p.addCurve(to: pt(44.72, 20.00), control1: pt(45.12, 22.94), control2: pt(44.98, 21.44))
            p.addLine(to: pt(24.00, 20.00))
            p.addLine(to: pt(24.00, 28.51))
            p.addLine(to: pt(35.84, 28.51))
            p.addCurve(to: pt(31.45, 35.15), control1: pt(35.33, 31.26), control2: pt(33.78, 33.59))
            p.addLine(to: pt(31.45, 40.67))
            p.addLine(to: pt(38.56, 40.67))
            p.addCurve(to: pt(45.12, 24.50), control1: pt(42.72, 36.84), control2: pt(45.12, 31.20))
            p.closeSubpath()
        return p
    }

    private func greenPath(_ pt: (CGFloat, CGFloat) -> CGPoint) -> Path {
        var p = Path()
            p.move(to: pt(24.00, 46.00))
            p.addCurve(to: pt(38.56, 40.67), control1: pt(29.94, 46.00), control2: pt(34.92, 44.03))
            p.addLine(to: pt(31.45, 35.15))
            p.addCurve(to: pt(24.00, 37.25), control1: pt(29.48, 36.47), control2: pt(26.96, 37.25))
            p.addCurve(to: pt(11.69, 28.18), control1: pt(18.27, 37.25), control2: pt(13.42, 33.38))
            p.addLine(to: pt(4.34, 28.18))
            p.addLine(to: pt(4.34, 33.88))
            p.addCurve(to: pt(24.00, 46.00), control1: pt(7.96, 41.07), control2: pt(15.40, 46.00))
            p.closeSubpath()
        return p
    }

    private func yellowPath(_ pt: (CGFloat, CGFloat) -> CGPoint) -> Path {
        var p = Path()
            p.move(to: pt(11.69, 28.18))
            p.addCurve(to: pt(11.00, 24.00), control1: pt(11.25, 26.86), control2: pt(11.00, 25.45))
            p.addCurve(to: pt(11.69, 19.82), control1: pt(11.00, 22.55), control2: pt(11.25, 21.14))
            p.addLine(to: pt(11.69, 14.12))
            p.addLine(to: pt(4.34, 14.12))
            p.addCurve(to: pt(2.00, 24.00), control1: pt(2.85, 17.09), control2: pt(2.00, 20.45))
            p.addCurve(to: pt(4.34, 33.88), control1: pt(2.00, 27.55), control2: pt(2.85, 30.91))
            p.addLine(to: pt(11.69, 28.18))
            p.closeSubpath()
        return p
    }

    private func redPath(_ pt: (CGFloat, CGFloat) -> CGPoint) -> Path {
        var p = Path()
            p.move(to: pt(24.00, 10.75))
            p.addCurve(to: pt(32.41, 14.04), control1: pt(27.23, 10.75), control2: pt(30.13, 11.86))
            p.addLine(to: pt(38.72, 7.73))
            p.addCurve(to: pt(24.00, 2.00), control1: pt(34.91, 4.18), control2: pt(29.93, 2.00))
            p.addCurve(to: pt(4.34, 14.12), control1: pt(15.40, 2.00), control2: pt(7.96, 6.93))
            p.addLine(to: pt(11.69, 19.82))
            p.addCurve(to: pt(24.00, 10.75), control1: pt(13.42, 14.62), control2: pt(18.27, 10.75))
            p.closeSubpath()
        return p
    }
}

/// Logo Facebook.
///
/// Trên nền xanh thương hiệu thì dùng chữ "f" trắng trần — đúng cách Facebook trình
/// bày nút đăng nhập nền xanh. Đứng riêng thì mới vẽ cả vòng tròn xanh.
struct FacebookLogo: View {
    enum Style { case onBrandBackground, standalone }

    var size: CGFloat = 22
    var style: Style = .standalone

    private let brandBlue = Color(red: 0.094, green: 0.467, blue: 0.949) // #1877F2

    var body: some View {
        ZStack {
            if style == .standalone {
                Circle().fill(brandBlue)
            }
            Text("f")
                .font(.system(size: size * (style == .standalone ? 0.74 : 0.96),
                              weight: .bold, design: .rounded))
                .foregroundStyle(style == .standalone ? .white : Color.white)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Logo Apple dùng ký hiệu hệ thống — Apple cho phép dùng `apple.logo` cho đúng
/// mục đích này và nó tự khớp với độ đậm chữ xung quanh.
struct AppleLogo: View {
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: "apple.logo")
            .font(.system(size: size * 0.86, weight: .medium))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
