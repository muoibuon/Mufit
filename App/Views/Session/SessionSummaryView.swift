import SwiftUI
import SwiftData

/// Tổng kết sau buổi tập: hiệu suất reps, khối lượng, nhóm cơ đã chạm tới.
struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.date) private var allSessions: [WorkoutSession]

    let session: WorkoutSession
    let calories: Double

    private var rate: Double { session.completionRate }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        ProgressRing(progress: rate, lineWidth: 14, tint: tint, isOverGoalBad: false)
                        VStack(spacing: 2) {
                            Text("\(Int(rate * 100))%")
                                .font(.largeTitle.bold().monospacedDigit())
                            Text("hiệu suất")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150)
                    .padding(.top, 12)

                    Text(verdict)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        StatTile(value: "\(session.actualRepTotal)/\(session.plannedRepTotal)", caption: "Reps thực tế / dự kiến", systemImage: "repeat")
                        StatTile(value: Fmt.int(session.completedVolumeKg), unit: "kg", caption: "Tổng khối lượng", systemImage: "scalemass")
                        StatTile(value: Fmt.int(calories), unit: "kcal", caption: "Đã đốt", systemImage: "flame.fill")
                    }

                    Card(title: "Từng bài tập", systemImage: "list.bullet.rectangle") {
                        ForEach(session.orderedExercises) { se in
                            let planned = se.orderedSets.reduce(0) { $0 + $1.targetReps }
                            let actual = se.orderedSets.reduce(0) { $0 + ($1.actualReps ?? 0) }
                            let r = planned > 0 ? Double(actual) / Double(planned) : 0

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(se.exercise?.name ?? "Bài tập")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(actual)/\(planned) reps")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.brand.mutedFill())
                                        Capsule()
                                            .fill(r >= 1 ? Color.brandGreen : (r >= 0.7 ? Color.brandWarm : Color.brandRed))
                                            .frame(width: geo.size.width * min(r, 1))
                                    }
                                }
                                .frame(height: 6)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Card(title: "Nhóm cơ đã tập", systemImage: "figure.strengthtraining.traditional") {
                        let muscles = Array(session.musclesWorked).sorted { $0.label < $1.label }
                        if muscles.isEmpty {
                            Text("Chưa xác định được nhóm cơ.").font(.footnote).foregroundStyle(.secondary)
                        } else {
                            FlowChips(items: muscles.map(\.label))
                        }
                    }

                    Card(title: "Cảnh báo cân đối nhóm cơ", systemImage: "exclamationmark.triangle") {
                        let alerts = MuscleBalanceAnalyzer.alerts(sessions: allSessions)
                        ForEach(alerts.prefix(3)) { a in
                            AlertRow(alert: a)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Tổng kết")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Xong") { dismiss() } }
            }
        }
    }

    private var tint: Color {
        if rate >= 1 { return .brandGreen }
        if rate >= 0.7 { return .brandWarm }
        return .brandRed
    }

    private var verdict: String {
        if rate >= 1.0 {
            return "Hoàn thành trọn vẹn kế hoạch. Buổi sau có thể tăng tạ khoảng 2.5-5% hoặc thêm 1 rep mỗi set."
        } else if rate >= 0.9 {
            return "Gần đạt kế hoạch. Giữ nguyên mức tạ và cố hoàn thành đủ reps trước khi tăng tải."
        } else if rate >= 0.7 {
            return "Hụt khá nhiều reps so với dự kiến. Có thể do tạ hơi nặng, ngủ thiếu hoặc chưa ăn đủ trước tập."
        } else if rate > 0 {
            return "Buổi tập hụt nhiều. Cân nhắc giảm tạ 5-10% và xem lại phục hồi, dinh dưỡng, giấc ngủ."
        } else {
            return "Chưa ghi nhận set nào hoàn thành."
        }
    }
}

/// Hiển thị danh sách nhãn tự xuống dòng.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.brand.mutedFill(), in: Capsule())
                    .lineLimit(1)
            }
        }
    }
}

struct AlertRow: View {
    let alert: MuscleBalanceAnalyzer.Alert

    private var tint: Color {
        switch alert.severity {
        case .info: return .brand
        case .warning: return .brandWarm
        case .critical: return .brandRed
        }
    }

    private var icon: String {
        switch alert.severity {
        case .info: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title).font(.subheadline.weight(.semibold))
                Text(alert.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
