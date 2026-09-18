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

    private let resting = Color(red: 0.61, green: 0.27, blue: 0.28)
    private let active = Color(red: 0.08, green: 0.57, blue: 0.39)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                anatomyPath(Self.outline, size: size)
                    .fill(LinearGradient(colors: [Color(red: 0.76, green: 0.69, blue: 0.65),
                                                  Color(red: 0.95, green: 0.88, blue: 0.81),
                                                  Color(red: 0.77, green: 0.69, blue: 0.64)],
                                         startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
                anatomyPath(Self.outline, size: size)
                    .stroke(Color(red: 0.38, green: 0.28, blue: 0.27).opacity(0.48), lineWidth: 1.2)
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 0.97, green: 0.90, blue: 0.83),
                                                  Color(red: 0.79, green: 0.70, blue: 0.65)],
                                         center: .init(x: 0.38, y: 0.32), startRadius: 0,
                                         endRadius: size.width * 0.13))
                    .frame(width: size.width * 0.16, height: size.height * 0.095)
                    .position(x: size.width / 2, y: size.height * 0.063)
                    .shadow(color: .black.opacity(0.14), radius: 3, y: 2)
                anatomyPath(rear ? Self.backLandmarks : Self.frontLandmarks, size: size)
                    .stroke(Color(red: 0.43, green: 0.31, blue: 0.29).opacity(layer == .superficial ? 0.17 : 0.29),
                            style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
                    .allowsHitTesting(false).accessibilityHidden(true)
                if layer != .superficial {
                    ForEach(Array(MuscleAnatomyGeometry.regions(rear: rear, layer: .superficial).enumerated()), id: \.offset) { _, region in
                        anatomyPath(region.path, size: size)
                            .fill(resting.opacity(0.11))
                            .overlay { anatomyPath(region.path, size: size).stroke(Color(red: 0.45, green: 0.31, blue: 0.30).opacity(0.22), lineWidth: 0.6) }
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                if layer == .deep {
                    ForEach(Array(MuscleAnatomyGeometry.regions(rear: rear, layer: .intermediate).enumerated()), id: \.offset) { _, region in
                        anatomyPath(region.path, size: size)
                            .fill(resting.opacity(0.07))
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                    let shape = anatomyPath(region.path, size: size)
                    let color = trained.contains(region.muscle) ? active : (hasGroupActivity(region.muscle) ? Color(red: 0.72, green: 0.52, blue: 0.22) : resting)
                    Button { select(region.muscle) } label: {
                        ZStack {
                            muscleSurface(region: region, size: size, color: color, mirror: false)
                            muscleSurface(region: region, size: size, color: color, mirror: true)
                        }
                        .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(region.muscle.label + ", " + region.muscle.latin)
                    .accessibilityValue(trained.contains(region.muscle) ? "Đã ghi nhận bài liên quan tuần này, ước tính" : (hasGroupActivity(region.muscle) ? "Nhóm cơ đã tập, chưa xác định cơ này" : "Chưa đủ dữ liệu cho cơ này"))
                    .accessibilityHint("Mở tần suất, gợi ý và ghi chú")
                }
            }
        }
        .aspectRatio(240.0 / 520.0, contentMode: .fit)
    }

    private var regions: [MuscleAnatomyGeometry.Region] {
        MuscleAnatomyGeometry.regions(rear: rear, layer: layer)
    }

    private func hasGroupActivity(_ muscle: AnatomicalMuscle) -> Bool {
        muscle.group.map { relatedGroups.contains($0) } ?? false
    }

    private func muscleSurface(region: MuscleAnatomyGeometry.Region, size: CGSize,
                               color: Color, mirror: Bool) -> some View {
        let shape = anatomyPath(region.path, size: size, mirror: mirror)
        let bounds = shape.boundingRect
        return shape.fill(LinearGradient(stops: [
            .init(color: color.opacity(0.72), location: 0),
            .init(color: color, location: 0.30),
            .init(color: color.opacity(0.91), location: 0.63),
            .init(color: color.opacity(0.60), location: 1)
        ], startPoint: mirror ? .topTrailing : .topLeading,
           endPoint: mirror ? .bottomLeading : .bottomTrailing))
        .shadow(color: .black.opacity(0.24), radius: 2, x: mirror ? -1 : 1, y: 1.5)
        .overlay {
            shape.fill(RadialGradient(colors: [.white.opacity(0.38), .clear, .black.opacity(0.31)],
                                      center: mirror ? .init(x: 0.70, y: 0.28) : .init(x: 0.30, y: 0.28),
                                      startRadius: 0, endRadius: max(bounds.width, bounds.height) * 0.8))
                .allowsHitTesting(false)
        }
        .overlay {
            fibers(size: size, direction: region.fiber)
                .stroke(Color(red: 1, green: 0.88, blue: 0.78).opacity(0.22), lineWidth: 0.5)
                .clipShape(shape)
                .allowsHitTesting(false)
        }
        .overlay {
            shape.stroke(Color(red: 0.31, green: 0.16, blue: 0.18).opacity(0.56), lineWidth: 1.2)
                .allowsHitTesting(false)
        }
        .overlay {
            shape.stroke(highlighted == region.muscle ? Color.blue : Color.white.opacity(0.42),
                         lineWidth: highlighted == region.muscle ? 2.5 : 0.65)
                .allowsHitTesting(false)
        }
    }

    private func point(_ x: Double, _ y: Double, size: CGSize) -> CGPoint {
        // Smooth proportions keep every path and hit region continuous at the joints.
        let scale: Double
        if sex == .female {
            let stops: [(Double, Double)] = [(0, 0.94), (80, 0.92), (145, 0.88),
                                             (200, 0.90), (255, 1.08), (320, 1.05),
                                             (400, 1.00), (520, 0.98)]
            let upper = stops.firstIndex { y <= $0.0 } ?? stops.count - 1
            if upper == 0 { scale = stops[0].1 }
            else {
                let lower = stops[upper - 1]
                let next = stops[upper]
                let t = (y - lower.0) / (next.0 - lower.0)
                scale = lower.1 + (next.1 - lower.1) * t
            }
        } else { scale = 1 }
        return CGPoint(x: (120 + (x - 120) * scale) / 240 * size.width, y: y / 520 * size.height)
    }

    private func anatomyPath(_ specification: String, size: CGSize, mirror selectedMirror: Bool? = nil) -> Path {
        let tokens = specification.split(separator: " ").map(String.init)
        var path = Path()
        for mirror in selectedMirror.map({ [$0] }) ?? [false, true] {
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

    private static let outline = "M 120 58 L 107 58 Q 105 65 103 70 L 78 79 Q 58 77 51 94 Q 47 102 46 117 L 44 155 Q 34 181 29 218 L 21 252 Q 20 264 27 265 Q 33 266 37 251 L 45 221 Q 53 203 59 183 L 71 154 L 80 135 Q 78 169 82 190 L 91 216 Q 80 238 76 259 Q 71 292 77 328 L 82 366 Q 75 385 75 411 Q 76 445 82 481 L 75 496 Q 69 506 89 505 L 99 502 L 101 482 Q 99 453 98 441 L 104 406 L 103 370 L 114 316 L 120 288 Z"

    private static let frontLandmarks = "M 120 83 Q 103 77 86 83 M 120 85 L 120 135 M 112 139 L 112 228 M 84 137 Q 98 148 113 145 M 85 159 Q 97 168 111 166 M 87 181 Q 99 190 112 188 M 89 204 Q 100 211 112 209 M 82 230 Q 91 224 100 235 M 90 365 Q 96 371 102 365 M 87 449 Q 92 455 97 450"
    private static let backLandmarks = "M 120 84 L 120 235 M 79 90 Q 91 93 100 102 Q 99 119 88 135 M 83 136 Q 100 145 113 150 M 89 217 Q 101 226 119 230 M 90 276 Q 104 285 119 281 M 81 370 Q 91 377 101 371 M 81 447 Q 89 455 98 447"
}
