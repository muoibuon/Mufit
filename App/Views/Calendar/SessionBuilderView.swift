import SwiftUI
import SwiftData

/// Setup thủ công một buổi tập: chọn bài, số set, số reps, kiểu set.
struct SessionBuilderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var weatherStore: WeatherStore

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    /// Nếu truyền vào một buổi đã có thì màn hình chuyển sang chế độ sửa.
    var existing: WorkoutSession?
    var date: Date

    @State private var title: String = ""
    @State private var sessionDate: Date = .now
    @State private var note: String = ""
    @State private var draft: [DraftExercise] = []
    @State private var showPicker = false
    @State private var repeatWeekly = false
    @State private var showRepeatOptions = false
    /// Số tuần sẽ nhân bản thêm, không tính buổi gốc.
    @State private var repeatWeeks = 8

    init(session: WorkoutSession) {
        self.existing = session
        self.date = session.date
        _title = State(initialValue: session.title)
        _sessionDate = State(initialValue: session.date)
        _note = State(initialValue: session.note)
        _draft = State(initialValue: session.orderedExercises.map(DraftExercise.init(from:)))
    }

    init(date: Date) {
        self.existing = nil
        self.date = date
        _title = State(initialValue: Self.defaultTitle(for: date))
        _sessionDate = State(initialValue: date)
    }

    private static func defaultTitle(for date: Date) -> String {
        "Buổi tập " + Fmt.dayMonth.string(from: date)
    }

    private var bodyWeight: Double { measurements.first?.weightKg ?? 70 }

    /// Ước lượng calo của buổi đang soạn, cập nhật ngay khi chỉnh set/reps.
    private var estimatedCalories: Double {
        var total: Double = 0
        for d in draft {
            let met = d.exercise?.met ?? 5.0
            let rest = d.supersetGroup == nil ? d.restSeconds : 0
            for s in d.sets {
                let reps = Double(s.targetReps + s.dropReps.reduce(0, +))
                let minutes = (reps * 3.0 + Double(rest) * 0.35) / 60
                total += met * 3.5 * bodyWeight / 200 * minutes * s.setType.intensityFactor
            }
        }
        return total * EnergyCalculator.thermalMultiplier(for: weatherStore.today)
    }

    private var totalSets: Int { draft.reduce(0) { $0 + $1.sets.count } }

    private var previousSession: WorkoutSession? {
        sessions.first {
            $0.date < sessionDate && $0.status != .skipped && !$0.orderedExercises.isEmpty
        }
    }

    var body: some View {
        Form {
            if existing == nil && draft.isEmpty, let previousSession {
                Section {
                    Button {
                        title = previousSession.title.hasPrefix("Buổi tập ")
                            ? Self.defaultTitle(for: sessionDate) : previousSession.title
                        note = previousSession.note
                        draft = previousSession.orderedExercises.enumerated().map {
                            DraftExercise(repeating: $0.element, order: $0.offset)
                        }
                    } label: {
                        Label("Dùng lại buổi gần nhất", systemImage: "arrow.counterclockwise")
                    }
                    Text("\(previousSession.title) · \(previousSession.orderedExercises.count) bài · \(previousSession.allSets.count) set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Bắt đầu nhanh")
                } footer: {
                    Text("Chỉ sao chép kế hoạch. Kết quả tập và trạng thái hoàn thành bắt đầu lại từ đầu.")
                }
            }

            Section("Thông tin buổi tập") {
                TextField("Tên buổi tập", text: $title)
                DatePicker("Ngày", selection: $sessionDate, displayedComponents: [.date, .hourAndMinute])
                TextField("Ghi chú", text: $note, axis: .vertical)
                    .lineLimit(1...3)
            }

            if existing == nil {
                Section {
                    DisclosureGroup(isExpanded: $showRepeatOptions) {
                        Toggle(isOn: $repeatWeekly) {
                            Text("Lặp vào \(Fmt.weekdayName(sessionDate)) hàng tuần")
                        }
                        if repeatWeekly {
                            Picker("Lặp trong", selection: $repeatWeeks) {
                                Text("4 tuần").tag(4)
                                Text("8 tuần").tag(8)
                                Text("12 tuần").tag(12)
                                Text("24 tuần").tag(24)
                            }
                        }
                    } label: {
                        Text(repeatWeekly ? "Lặp lại \(repeatWeeks) tuần" : "Lặp lại hàng tuần")
                    }
                } footer: {
                    if repeatWeekly {
                        Text("Sẽ tạo thêm \(repeatWeeks) buổi nữa, mỗi tuần một buổi vào \(Fmt.weekdayName(sessionDate)), cùng giờ và cùng nội dung bài tập. Sau này sửa hoặc xoá từng buổi riêng lẻ vẫn được.")
                            .font(.caption2)
                    }
                }
            }

            if !draft.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        StatTile(value: "\(draft.count)", caption: "Bài tập", systemImage: "list.bullet")
                        StatTile(value: "\(totalSets)", caption: "Tổng set", systemImage: "square.stack.3d.up")
                        StatTile(value: Fmt.int(estimatedCalories), unit: "kcal", caption: "Dự kiến", systemImage: "flame.fill")
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                }
            }

            ForEach($draft) { $item in
                DraftExerciseSection(
                    item: $item,
                    onDelete: { draft.removeAll { $0.id == item.id } },
                    supersetPartners: draft.filter { $0.id != item.id }.map(\.displayName)
                )
            }

            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Thêm bài tập", systemImage: "plus.circle.fill")
                }
            }

            if !draft.isEmpty {
                Section {
                    Text("Superset: đặt cùng một số nhóm cho 2 bài trở lên để tập nối tiếp không nghỉ. Drop set: nhập các mức tạ giảm dần ngay trong set.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(existing == nil ? "Setup buổi tập" : "Sửa buổi tập")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(repeatWeekly && existing == nil ? "Lưu \(repeatWeeks + 1) buổi" : "Lưu") { save() }
                    .disabled(draft.isEmpty || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { configured in
                var item = configured
                item.order = draft.count
                draft.append(item)
            }
        }
    }

    private func save() {
        let base: WorkoutSession
        if let existing {
            base = existing
            // Xoá các bài cũ rồi dựng lại theo bản nháp hiện tại.
            for se in base.exercises { context.delete(se) }
            base.exercises.removeAll()
        } else {
            base = WorkoutSession(date: sessionDate, title: title, note: note)
            context.insert(base)
        }

        base.title = title
        base.date = sessionDate
        base.note = note
        populate(base)

        if existing == nil && repeatWeekly {
            let calendar = Calendar.current
            for week in 1...repeatWeeks {
                guard let day = calendar.date(byAdding: .weekOfYear, value: week, to: sessionDate) else { continue }
                let copy = WorkoutSession(date: day, title: title, note: note)
                context.insert(copy)
                populate(copy)
            }
        }

        try? context.save()
        dismiss()
    }

    /// Dựng bài tập và các set của một buổi từ bản nháp.
    private func populate(_ session: WorkoutSession) {
        for (index, d) in draft.enumerated() {
            let se = SessionExercise(
                order: index,
                exercise: d.exercise,
                restSeconds: d.restSeconds,
                supersetGroup: d.supersetGroup,
                note: d.note
            )
            se.session = session
            se.anatomyTargetRaws = d.anatomyTargetRaws
            context.insert(se)

            for (si, s) in d.sets.enumerated() {
                let set = s.makeSetLog(index: si)
                set.sessionExercise = se
                context.insert(set)
            }
        }
    }
}

// MARK: - Bản nháp (chỉnh trong bộ nhớ, chỉ ghi vào SwiftData khi bấm Lưu)

/// Một khối bài tập trong form setup.
struct DraftExerciseSection: View {
    @Binding var item: DraftExercise
    var onDelete: () -> Void
    var supersetPartners: [String]
    @State private var showDetails = false

    private var setSummary: String {
        guard let first = item.sets.first else { return "Chưa có set" }
        let uniform = item.sets.allSatisfy {
            $0.targetReps == first.targetReps && $0.weightKg == first.weightKg && $0.setType == first.setType
        }
        return uniform
            ? "\(item.sets.count) set · \(first.targetReps) reps × \(String(format: "%g", first.weightKg)) kg"
            : "\(item.sets.count) set · thông số riêng từng set"
    }

    var body: some View {
        Section {
            Text(setSummary)
                .font(.subheadline)
            Button {
                withAnimation { showDetails.toggle() }
            } label: {
                Label(showDetails ? "Ẩn chi tiết" : "Chỉnh chi tiết", systemImage: "slider.horizontal.3")
                    .font(.subheadline)
            }

            if showDetails {
                AnatomicalTargetPicker(exercise: item.exercise, targets: $item.anatomyTargetRaws)
                ForEach($item.sets) { $set in
                    DraftSetRow(set: $set, index: (item.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1)
                }
                .onDelete { offsets in
                    guard offsets.count < item.sets.count else { return }
                    item.sets.remove(atOffsets: offsets)
                }

                Button {
                    item.sets.append(item.sets.last.map { DraftSet(setType: $0.setType, targetReps: $0.targetReps, weightKg: $0.weightKg) } ?? DraftSet())
                } label: {
                    Label("Thêm set", systemImage: "plus")
                        .font(.subheadline)
                }

                HStack {
                    Text("Nghỉ giữa set")
                    Spacer()
                    Picker("", selection: $item.restSeconds) {
                        ForEach([30, 45, 60, 90, 120, 150, 180], id: \.self) { s in
                            Text("\(s)s").tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Nhóm superset")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { item.supersetGroup ?? 0 },
                        set: { item.supersetGroup = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Không").tag(0)
                        ForEach(1...4, id: \.self) { g in Text("Nhóm \(g)").tag(g) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                    if let ex = item.exercise {
                        Text("\(ex.primaryMuscle.label) · \(ex.equipment.label) · MET \(String(format: "%.1f", ex.met))")
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

/// Một dòng set trong form setup: kiểu set, reps, tạ, và phần drop nếu là drop set.
struct DraftSetRow: View {
    @Binding var set: DraftSet
    var index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Set \(index)")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 52, alignment: .leading)

                Picker("", selection: $set.setType) {
                    ForEach(SetType.allCases) { t in Text(t.label).tag(t) }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Spacer()
            }

            HStack(spacing: 12) {
                Stepper(value: $set.targetReps, in: 1...50) {
                    Text("\(set.targetReps) reps")
                        .font(.subheadline.monospacedDigit())
                }
                .fixedSize()

                Spacer()

                HStack(spacing: 4) {
                    TextField("kg", value: $set.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                    Text("kg").font(.caption).foregroundStyle(.secondary)
                }
            }

            if set.setType == .dropSet {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(set.dropWeights.enumerated()), id: \.offset) { i, _ in
                        HStack(spacing: 8) {
                            Text("Drop \(i + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .leading)
                            TextField("kg", value: Binding(
                                get: { set.dropWeights[i] },
                                set: { set.dropWeights[i] = $0 }
                            ), format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 56)
                            Text("kg ×").font(.caption2).foregroundStyle(.secondary)
                            TextField("reps", value: Binding(
                                get: { i < set.dropReps.count ? set.dropReps[i] : 0 },
                                set: {
                                    while set.dropReps.count <= i { set.dropReps.append(0) }
                                    set.dropReps[i] = $0
                                }
                            ), format: .number)
                                .keyboardType(.numberPad)
                                .frame(width: 44)
                            Text("reps").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                set.dropWeights.remove(at: i)
                                if i < set.dropReps.count { set.dropReps.remove(at: i) }
                            } label: {
                                Image(systemName: "minus.circle").font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button {
                        let next = (set.dropWeights.last ?? set.weightKg) * 0.8
                        set.dropWeights.append((next / 2.5).rounded() * 2.5)
                        set.dropReps.append(max(4, set.targetReps - 2))
                    } label: {
                        Label("Thêm mức drop", systemImage: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 2)
    }
}
