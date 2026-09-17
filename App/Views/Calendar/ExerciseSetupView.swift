import SwiftUI

/// Khai báo set ngay khi vừa chọn bài tập, trước khi bài được đưa vào buổi tập.
///
/// Trước đây bài được thêm với 3 set mặc định rồi mới chỉnh lại trong màn setup —
/// vừa thừa thao tác vừa dễ quên sửa. Giờ hỏi luôn tại đây, bài đưa vào là đã đúng.
struct ExerciseSetupView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    var onDone: (DraftExercise) -> Void

    @State private var draft: DraftExercise
    @State private var quickReps: Int = 10
    @State private var quickWeight: Double = 20
    @State private var showAdvanced = false

    init(exercise: Exercise, onDone: @escaping (DraftExercise) -> Void) {
        self.exercise = exercise
        self.onDone = onDone
        let reps = exercise.equipment == .bodyweight ? 12 : 10
        let weight = exercise.equipment == .bodyweight ? 0.0 : 20.0
        var initial = DraftExercise(exercise: exercise, order: 0)
        initial.sets = initial.sets.map {
            var set = $0
            set.targetReps = reps
            set.weightKg = weight
            return set
        }
        _draft = State(initialValue: initial)
        _quickReps = State(initialValue: reps)
        _quickWeight = State(initialValue: weight)
    }

    private var setCount: Binding<Int> {
        Binding(
            get: { draft.sets.count },
            set: { newValue in
                let target = max(1, min(newValue, 12))
                while draft.sets.count < target {
                    // Set mới kế thừa thông số của set cuối để đỡ phải nhập lại.
                    let last = draft.sets.last
                    draft.sets.append(DraftSet(
                        setType: last?.setType ?? .normal,
                        targetReps: last?.targetReps ?? quickReps,
                        weightKg: last?.weightKg ?? quickWeight
                    ))
                }
                while draft.sets.count > target {
                    draft.sets.removeLast()
                }
            }
        )
    }

    private var repsForAllSets: Binding<Int> {
        Binding(get: { quickReps }, set: { value in
            quickReps = value
            for index in draft.sets.indices { draft.sets[index].targetReps = value }
        })
    }

    private var weightForAllSets: Binding<Double> {
        Binding(get: { quickWeight }, set: { value in
            quickWeight = value
            for index in draft.sets.indices { draft.sets[index].weightKg = value }
        })
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.headline)
                    Text("\(exercise.primaryMuscle.label) · \(exercise.equipment.label) · MET \(String(format: "%.1f", exercise.met))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Stepper(value: setCount, in: 1...12) {
                    Text("\(draft.sets.count) set")
                        .font(.body.monospacedDigit())
                }
                Stepper(value: repsForAllSets, in: 1...50) {
                    Text("\(quickReps) reps mỗi set").font(.body.monospacedDigit())
                }
                HStack {
                    Text("Mức tạ mỗi set")
                    Spacer()
                    TextField("kg", value: weightForAllSets, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("kg").font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Thiết lập nhanh")
            } footer: {
                Text("Đổi reps hoặc mức tạ ở đây sẽ áp dụng cho mọi set.")
                    .font(.caption2)
            }

            Section {
                Button {
                    withAnimation { showAdvanced.toggle() }
                } label: {
                    Label(showAdvanced ? "Ẩn thiết lập nâng cao" : "Thiết lập nâng cao", systemImage: "slider.horizontal.3")
                }
            }

            if showAdvanced {
                Section("Cơ trên bản đồ giải phẫu") {
                    AnatomicalTargetPicker(exercise: exercise, targets: $draft.anatomyTargetRaws)
                }

                Section("Chỉnh từng set") {
                    ForEach($draft.sets) { $set in
                        DraftSetRow(set: $set,
                                    index: (draft.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1)
                    }
                    .onDelete { offsets in
                        guard offsets.count < draft.sets.count else { return }
                        draft.sets.remove(atOffsets: offsets)
                    }
                }

                Section {
                    HStack {
                        Text("Nghỉ giữa set")
                        Spacer()
                        Picker("", selection: $draft.restSeconds) {
                            ForEach([30, 45, 60, 90, 120, 150, 180], id: \.self) { Text("\($0)s").tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("Nhóm superset")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { draft.supersetGroup ?? 0 },
                            set: { draft.supersetGroup = $0 == 0 ? nil : $0 }
                        )) {
                            Text("Không").tag(0)
                            ForEach(1...4, id: \.self) { Text("Nhóm \($0)").tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    TextField("Ghi chú cho bài này", text: $draft.note)
                } header: {
                    Text("Buổi tập nâng cao")
                } footer: {
                    Text("Drop set: chọn kiểu set ở phần chỉnh từng set. Các bài cùng số nhóm superset được tập nối tiếp.")
                        .font(.caption2)
                }
            }
        }
        .navigationTitle("Thiết lập bài tập")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Thêm") {
                    onDone(draft)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}
