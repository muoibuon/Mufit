import SwiftUI
import SwiftData

/// Màn hình thực hiện buổi tập: xác nhận từng set, nhập reps thực tế,
/// rồi tổng hợp hiệu suất khi kết thúc.
struct ActiveSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var weatherStore: WeatherStore

    @Bindable var session: WorkoutSession

    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var showSummary = false
    @State private var showEdit = false
    @State private var confirmDelete = false

    private var bodyWeight: Double { measurements.first?.weightKg ?? 70 }

    private var calories: Double {
        EnergyCalculator.caloriesForSession(session, bodyWeightKg: bodyWeight, weather: weatherStore.today)
    }

    private var completedSetCount: Int { session.allSets.filter(\.isCompleted).count }

    var body: some View {
        List {
            headerSection

            if session.status == .planned {
                Section("Bài tập dự kiến") {
                    ForEach(session.orderedExercises) { se in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(se.exercise?.name ?? "Bài tập")
                            if let exercise = se.exercise {
                                Text(exercise.primaryMuscle.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                ForEach(session.orderedExercises) { se in
                    exerciseSection(se)
                }
            }

            Section {
                if session.status == .planned {
                    Button {
                        session.status = .inProgress
                        session.startedAt = .now
                        session.recordedTemperatureC = weatherStore.today?.meanTempC
                        try? context.save()
                    } label: {
                        Label("Bắt đầu buổi tập", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProminentActionStyle(
                        background: IconPalette.training,
                        foreground: .black
                    ))
                }

                if session.status == .inProgress {
                    Button {
                        finish()
                    } label: {
                        Label("Hoàn thành buổi tập", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProminentActionStyle(
                        background: .brandGreen,
                        foreground: ThemeState.shared.isHighContrast ? .white : .black
                    ))
                }

                if session.status == .completed {
                    Button {
                        showSummary = true
                    } label: {
                        Label("Xem tổng kết", systemImage: "chart.bar.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if session.status != .completed {
                    Button(role: .destructive) {
                        session.status = .skipped
                        try? context.save()
                        dismiss()
                    } label: {
                        Label("Đánh dấu bỏ buổi", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Xoá buổi tập", systemImage: "trash")
                }
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: { Image(systemName: "slider.horizontal.3") }
            }
        }
        .navigationDestination(isPresented: $showEdit) {
            SessionBuilderView(session: session)
        }
        .sheet(isPresented: $showSummary) {
            SessionSummaryView(session: session, calories: calories)
        }
        .alert("Xoá buổi tập này?", isPresented: $confirmDelete) {
            Button("Xoá", role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Toàn bộ set đã ghi của buổi này sẽ mất. Không hoàn tác được.")
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                StatTile(value: "\(completedSetCount)/\(session.allSets.count)", caption: "Set đã xong", systemImage: "checkmark.circle")
                StatTile(value: Fmt.int(calories), unit: "kcal", caption: "Đã đốt", systemImage: "flame.fill")
                StatTile(value: Fmt.int(session.completedVolumeKg), unit: "kg", caption: "Tổng khối lượng", systemImage: "scalemass")
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)

            if let temp = session.recordedTemperatureC {
                Text("Nhiệt độ lúc tập \(Int(temp))°C — calo đã nhân hệ số \(String(format: "%.2f", EnergyCalculator.thermalMultiplier(for: weatherStore.today))).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exerciseSection(_ se: SessionExercise) -> some View {
        Section {
            ForEach(se.orderedSets) { set in
                SetExecutionRow(set: set, isLocked: session.status == .planned)
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(se.exercise?.name ?? "Bài tập")
                    if let ex = se.exercise {
                        Text(ex.primaryMuscle.label + " · nghỉ \(se.restSeconds)s")
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let g = se.supersetGroup {
                    Text("Superset \(g)")
                        .font(.caption2.weight(.bold))
                        .textCase(nil)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.brand.mutedFill(), in: Capsule())
                        .foregroundStyle(Color.brand)
                }
                if se.isFullyLogged {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.brandGreen)
                }
            }
        }
    }

    private func finish() {
        session.status = .completed
        session.finishedAt = .now
        if session.startedAt == nil {
            session.startedAt = Calendar.current.date(byAdding: .minute, value: -45, to: .now)
        }
        // Set chưa bấm xác nhận coi như không tập: reps thực tế = 0.
        for set in session.allSets where !set.isCompleted {
            set.actualReps = 0
        }
        try? context.save()
        showSummary = true
    }
}

/// Một dòng set khi đang tập: bấm xác nhận, nhập reps thực tế.
struct SetExecutionRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: SetLog
    var isLocked: Bool

    @State private var draftReps: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    toggle()
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(set.isCompleted ? Color.brandGreen : Color.secondary)
                        .symbolEffect(.bounce, value: set.isCompleted)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(isLocked)

                Text("\(set.targetReps) reps × \(String(format: "%g", set.weightKg)) kg")
                    .font(.subheadline.monospacedDigit())
                    .strikethrough(set.isCompleted && (set.actualReps ?? 0) == 0)

                Spacer()

                if set.isCompleted, let actual = set.actualReps {
                    Text("\(actual)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(color(for: actual))
                        + Text(" / \(set.targetReps)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !set.dropWeights.isEmpty {
                Text("Drop: " + zip(set.dropWeights, set.dropReps)
                        .map { "\(String(format: "%g", $0.0))kg×\($0.1)" }
                        .joined(separator: " → "))
                    .font(.caption2)
                    .foregroundStyle(Color.brandWarm)
            }

            if set.isCompleted {
                HStack(spacing: 12) {
                    Stepper(value: Binding(
                        get: { set.actualReps ?? set.targetReps },
                        set: { set.actualReps = $0; try? context.save() }
                    ), in: 0...100) {
                        Text("Reps thực tế: \(set.actualReps ?? set.targetReps)")
                            .font(.caption.monospacedDigit())
                    }
                    .fixedSize()
                    Spacer()
                    if set.estimatedOneRepMax > 0 {
                        Text("1RM ≈ \(Int(set.estimatedOneRepMax)) kg")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(isLocked ? 0.55 : 1)
        .animation(.snappy, value: set.isCompleted)
        .sensoryFeedback(.success, trigger: set.isCompleted)
    }

    private func toggle() {
        if set.isCompleted {
            set.isCompleted = false
            set.actualReps = nil
            set.completedAt = nil
        } else {
            set.isCompleted = true
            set.actualReps = set.targetReps
            set.completedAt = .now
        }
        try? context.save()
    }

    private func color(for actual: Int) -> Color {
        if actual >= set.targetReps { return .brandGreen }
        if actual >= Int(Double(set.targetReps) * 0.7) { return .brandWarm }
        return .brandRed
    }
}
