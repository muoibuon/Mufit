import SwiftUI

struct AnatomicalTargetPicker: View {
    var exercise: Exercise?
    @Binding var targets: [String]?
    @State private var search = ""

    private var automatic: AnatomicalTrainingTracker.Targets {
        guard let exercise else { return .init() }
        return AnatomicalTrainingTracker.targets(slug: exercise.slug, isCustom: exercise.isCustom)
    }
    private var automaticNames: String {
        AnatomicalMuscle.allCases.filter { automatic.direct.contains($0) || automatic.assisting.contains($0) }
            .map(\.label).joined(separator: ", ")
    }
    private var selected: Set<String> { Set(targets ?? []) }

    var body: some View {
        DisclosureGroup(targets == nil ? "Cơ cụ thể: tự ước tính theo bài" : "Cơ cụ thể: đã chọn \(selected.count)") {
            Toggle("Tự ước tính với bài có hỗ trợ", isOn: Binding(
                get: { targets == nil },
                set: { targets = $0 ? nil : [] }
            ))
            if targets == nil {
                Text(automaticNames.isEmpty ? "Bài này chưa có ánh xạ. Tắt chế độ tự động để khai báo cơ cụ thể." : automaticNames)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Tìm tên cơ Việt / Latin", text: $search)
                ForEach(AnatomicalMuscle.allCases.filter {
                    search.isEmpty || $0.label.localizedStandardContains(search) || $0.latin.localizedStandardContains(search)
                }) { muscle in
                    Toggle(isOn: Binding(
                        get: { selected.contains(muscle.rawValue) },
                        set: { isOn in
                            var updated = selected
                            if isOn { updated.insert(muscle.rawValue) } else { updated.remove(muscle.rawValue) }
                            targets = updated.sorted()
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(muscle.label).font(.subheadline)
                            Text(muscle.latin).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Text("Khai báo theo bài thực hiện hoặc hướng dẫn chuyên môn. Chỉ hiệp thực sự hoàn thành trong buổi đã kết thúc mới tạo dấu ✓. Việc chọn cơ không xác nhận cường độ hay độ an toàn của bài.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
