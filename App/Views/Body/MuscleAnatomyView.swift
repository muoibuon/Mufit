import SwiftUI

/// Original selective anatomy diagrams with separate named muscles and dissection layers.
/// Paths and hit regions share the same geometry at every size and for both figures.
struct MuscleAnatomyView: View {
    var sex: BiologicalSex
    var rear: Bool
    var layer: AnatomyLayer = .superficial
    var trained: Set<AnatomicalMuscle>
    var relatedGroups: Set<MuscleGroup> = []
    var highlighted: AnatomicalMuscle? = nil
    var select: (AnatomicalMuscle) -> Void

    private let resting = Color(red: 0.69, green: 0.36, blue: 0.34)
    private let active = Color(red: 0.10, green: 0.66, blue: 0.43)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                anatomyPath(Self.outline, size: size)
                    .fill(Color(red: 0.89, green: 0.86, blue: 0.81))
                anatomyPath(Self.outline, size: size)
                    .stroke(Color.primary.opacity(0.30), lineWidth: 1.2)
                Ellipse()
                    .fill(Color(red: 0.89, green: 0.86, blue: 0.81))
                    .frame(width: size.width * 0.16, height: size.height * 0.095)
                    .position(x: size.width / 2, y: size.height * 0.063)
                if layer != .superficial {
                    ForEach(Array(MuscleAnatomyGeometry.regions(rear: rear, layer: .superficial).enumerated()), id: \.offset) { _, region in
                        anatomyPath(region.path, size: size)
                            .fill(resting.opacity(0.08))
                            .overlay { anatomyPath(region.path, size: size).stroke(Color.primary.opacity(0.12), lineWidth: 0.5) }
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                    let shape = anatomyPath(region.path, size: size)
                    let color = trained.contains(region.muscle) ? active : (hasGroupActivity(region.muscle) ? Color(red: 0.72, green: 0.52, blue: 0.22) : resting)
                    Button { select(region.muscle) } label: {
                        shape.fill(LinearGradient(colors: [color.opacity(0.88), color], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay {
                                fibers(size: size, direction: region.fiber).stroke(Color.white.opacity(0.32), lineWidth: 0.7)
                                    .clipShape(shape)
                            }
                            .overlay { shape.stroke(highlighted == region.muscle ? Color.blue : Color.white.opacity(0.8), lineWidth: highlighted == region.muscle ? 2.5 : 1.1) }
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(region.muscle.label + ", " + region.muscle.latin)
                    .accessibilityValue(trained.contains(region.muscle) ? "Đã ghi nhận bài liên quan tuần này, ước tính" : (hasGroupActivity(region.muscle) ? "Nhóm cơ đã tập, chưa xác định cơ này" : "Chưa đủ dữ liệu cho cơ này"))
                    .accessibilityHint("Mở tần suất, gợi ý và ghi chú")
                }
                ForEach(visibleMuscles) { muscle in
                    if trained.contains(muscle), let anchor = regions.first(where: { $0.muscle == muscle })?.anchor {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white, active)
                            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                            .position(point(anchor.0, anchor.1, size: size))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .aspectRatio(240.0 / 520.0, contentMode: .fit)
    }

    private var visibleMuscles: [AnatomicalMuscle] {
        AnatomicalMuscle.allCases.filter { muscle in regions.contains { $0.muscle == muscle } }
    }

    private var regions: [MuscleAnatomyGeometry.Region] {
        MuscleAnatomyGeometry.regions(rear: rear, layer: layer)
    }

    private func hasGroupActivity(_ muscle: AnatomicalMuscle) -> Bool {
        muscle.group.map { relatedGroups.contains($0) } ?? false
    }

    private func point(_ x: Double, _ y: Double, size: CGSize) -> CGPoint {
        // Different shoulder/waist/pelvis outlines, with identical muscle group semantics.
        let scale: Double
        if sex == .female {
            if y < 70 { scale = 0.95 }
            else if y < 150 { scale = 0.90 }
            else if y < 220 { scale = 0.90 + (y - 150) / 70 * 0.10 }
            else if y < 300 { scale = 1.10 }
            else { scale = 1.03 }
        } else { scale = 1 }
        return CGPoint(x: (120 + (x - 120) * scale) / 240 * size.width, y: y / 520 * size.height)
    }

    private func anatomyPath(_ specification: String, size: CGSize) -> Path {
        let tokens = specification.split(separator: " ").map(String.init)
        var path = Path()
        for mirror in [false, true] {
            var index = 0
            func nextPoint() -> CGPoint {
                let x = Double(tokens[index])!
                let y = Double(tokens[index + 1])!
                index += 2
                return point(mirror ? 240 - x : x, y, size: size)
            }
            while index < tokens.count {
                let command = tokens[index]; index += 1
                switch command {
                case "M": path.move(to: nextPoint())
                case "L": path.addLine(to: nextPoint())
                case "Q":
                    let control = nextPoint()
                    path.addQuadCurve(to: nextPoint(), control: control)
                case "Z": path.closeSubpath()
                default: break
                }
            }
        }
        return path
    }

    private func fibers(size: CGSize, direction: MuscleAnatomyGeometry.Fiber) -> Path {
        Path { path in
            switch direction {
            case .longitudinal:
                for x in stride(from: 20.0, through: 220.0, by: 4.0) {
                    path.move(to: point(x, 50, size: size))
                    path.addLine(to: point(x, 490, size: size))
                }
            case .transverse:
                for y in stride(from: 50.0, through: 490.0, by: 5.0) {
                    path.move(to: point(20, y, size: size))
                    path.addLine(to: point(220, y, size: size))
                }
            case .fan, .diagonal:
                for y in stride(from: 30.0, through: 510.0, by: 6.0) {
                    let bend = direction == .fan ? 12.0 : 32.0
                    path.move(to: point(20, y - 24, size: size))
                    path.addQuadCurve(to: point(120, y + bend, size: size), control: point(80, y - 15, size: size))
                    path.move(to: point(220, y - 24, size: size))
                    path.addQuadCurve(to: point(120, y + bend, size: size), control: point(160, y - 15, size: size))
                }
            }
        }
    }

    private static let outline = "M 120 58 L 107 58 L 105 69 L 77 79 Q 55 77 49 101 L 45 156 Q 32 186 29 221 L 21 252 Q 21 264 28 263 L 39 245 L 44 218 L 59 181 L 71 154 L 80 135 L 83 183 L 91 215 Q 75 245 74 278 L 76 329 L 82 366 Q 69 393 76 435 L 82 481 L 74 497 Q 73 505 99 501 L 101 482 L 98 446 L 105 405 L 103 370 L 114 316 L 120 288 Z"
}
