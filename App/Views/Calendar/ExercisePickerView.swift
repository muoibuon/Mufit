import SwiftUI
import SwiftData

/// Chọn bài tập từ thư viện, có tìm kiếm, lọc nhóm cơ, và tải thêm từ wger.de.
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var catalog: CatalogStore

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var profiles: [UserProfile]

    /// Trả về bài tập đã khai báo đủ set, sẵn sàng đưa vào buổi tập.
    var onPick: (DraftExercise) -> Void

    @State private var search = ""
    @State private var muscleFilter: MuscleGroup?
    @State private var showCustomSheet = false
    @State private var configuring: Exercise?

    private var priorityMuscles: [MuscleGroup] {
        guard let p = profiles.first else { return [] }
        return ConditionAdvisor.priorityMuscles(for: p.conditions)
    }

    private var filtered: [Exercise] {
        exercises.filter { ex in
            let matchMuscle = muscleFilter == nil
                || ex.primaryMuscle == muscleFilter
                || ex.secondaryMuscles.contains(muscleFilter!)
            let matchText = search.isEmpty
                || ex.name.localizedCaseInsensitiveContains(search)
                || ex.primaryMuscle.label.localizedCaseInsensitiveContains(search)
            return matchMuscle && matchText
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !priorityMuscles.isEmpty && muscleFilter == nil && search.isEmpty {
                    Section("Gợi ý theo bệnh nền của bạn") {
                        Text("Nên ưu tiên: " + priorityMuscles.prefix(4).map(\.label).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip(nil, "Tất cả")
                            ForEach(MuscleGroup.allCases) { m in
                                chip(m, m.label)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))

                Section("\(filtered.count) bài tập") {
                    if filtered.isEmpty {
                        Text("Không tìm thấy bài nào. Thử tải thêm thư viện hoặc tự thêm bài.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(filtered) { ex in
                        Button {
                            configuring = ex
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(ex.name).font(.subheadline.weight(.medium))
                                    if ex.isCustom {
                                        Text("của bạn")
                                            .font(.caption2)
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(Color.brandGreen.mutedFill(), in: Capsule())
                                    }
                                }
                                Text("\(ex.primaryMuscle.label) · \(ex.equipment.label) · MET \(String(format: "%.1f", ex.met))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !ex.secondaryMuscles.isEmpty {
                                    Text("Phụ: " + ex.secondaryMuscles.map(\.label).joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button {
                        Task { await catalog.syncExercises(context: context) }
                    } label: {
                        if case .syncing(let msg) = catalog.exerciseSync {
                            HStack { ProgressView(); Text(msg).font(.footnote) }
                        } else {
                            Label("Tải thêm bài tập từ wger.de", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled({ if case .syncing = catalog.exerciseSync { return true } else { return false } }())

                    Button {
                        showCustomSheet = true
                    } label: {
                        Label("Tự thêm bài tập", systemImage: "plus.circle")
                    }

                    switch catalog.exerciseSync {
                    case .success(let m):
                        Text(m).font(.caption).foregroundStyle(Color.brandGreen)
                    case .failure(let m):
                        Text(m).font(.caption).foregroundStyle(Color.brandRed)
                    default:
                        EmptyView()
                    }
                } footer: {
                    Text("Thư viện offline lấy MET từ Compendium of Physical Activities (Ainsworth 2011). Dữ liệu tải thêm đến từ wger.de, giấy phép CC-BY-SA.")
                        .font(.caption2)
                }
            }
            .searchable(text: $search, prompt: "Tìm bài tập")
            .navigationTitle("Chọn bài tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .navigationDestination(item: $configuring) { exercise in
                ExerciseSetupView(exercise: exercise) { draft in
                    onPick(draft)
                    dismiss()
                }
            }
            .sheet(isPresented: $showCustomSheet) {
                CustomExerciseSheet { newExercise in
                    // Bài tự thêm cũng đi qua bước khai báo set như mọi bài khác.
                    configuring = newExercise
                }
            }
        }
    }

    private func chip(_ m: MuscleGroup?, _ label: String) -> some View {
        let isOn = muscleFilter == m
        return Button {
            muscleFilter = isOn ? nil : m
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(isOn ? Color.brand : Color.brand.mutedFill(), in: Capsule())
                .foregroundStyle(isOn ? Color.onBrand : Color.brand)
        }
        .buttonStyle(.plain)
    }
}

/// Tự thêm một bài tập không có trong thư viện.
struct CustomExerciseSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var onCreate: (Exercise) -> Void

    @State private var name = ""
    @State private var primary: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var met: Double = 5.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Bài tập") {
                    TextField("Tên bài tập", text: $name)
                    Picker("Nhóm cơ chính", selection: $primary) {
                        ForEach(MuscleGroup.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Dụng cụ", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section {
                    HStack {
                        Text("MET")
                        Spacer()
                        Text(String(format: "%.1f", met)).monospacedDigit()
                    }
                    Slider(value: $met, in: 2...12, step: 0.5)
                    Button("Dùng giá trị gợi ý cho nhóm cơ này") {
                        met = ExerciseCatalogService.metValue(for: primary, equipment: equipment)
                    }
                    .font(.footnote)
                } footer: {
                    Text("MET là chi phí năng lượng chuẩn hoá: 1 MET = mức tiêu hao lúc ngồi nghỉ. Bài đơn khớp nhẹ ≈ 3.5, compound nặng ≈ 6, cardio cường độ cao ≈ 9-11.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Bài tập của bạn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Thêm") {
                        let ex = Exercise(
                            slug: "custom-" + UUID().uuidString,
                            name: name.trimmingCharacters(in: .whitespaces),
                            primaryMuscle: primary,
                            equipment: equipment,
                            met: met,
                            sourceName: "Tự thêm",
                            isCustom: true
                        )
                        context.insert(ex)
                        try? context.save()
                        onCreate(ex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
