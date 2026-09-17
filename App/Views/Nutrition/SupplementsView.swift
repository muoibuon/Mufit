import SwiftUI
import SwiftData

/// Khai báo supplement đang dùng: tên + thành phần + liều.
struct SupplementsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Supplement.startedAt, order: .reverse) private var supplements: [Supplement]
    @Query private var profiles: [UserProfile]

    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                if supplements.isEmpty {
                    EmptyStateView(
                        systemImage: "pills",
                        title: "Chưa có supplement nào",
                        message: "Nhập tên và thành phần để app đối chiếu với khoảng trống dinh dưỡng và bệnh nền của bạn."
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(supplements) { s in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(s.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { s.isActive },
                                set: { s.isActive = $0; try? context.save() }
                            ))
                            .labelsHidden()
                        }
                        if !s.ingredients.isEmpty {
                            Text(s.ingredients).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(String(format: "%g", s.dosagePerDay)) \(s.unit)/ngày" + (s.timingNote.isEmpty ? "" : " · \(s.timingNote)"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(supplements[i]) }
                    try? context.save()
                }

                Section {
                    Text("""
                    Lưu ý tương tác thường gặp: canxi và sắt làm giảm hấp thu lẫn nhau — uống cách nhau ít nhất 2 giờ. \
                    Caffeine trong pre-workout sau 14h ảnh hưởng giấc ngủ. Nếu đang dùng thuốc điều trị, hỏi bác sĩ hoặc \
                    dược sĩ trước khi thêm supplement mới.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddSupplementSheet() }
        }
    }
}

struct AddSupplementSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ingredients = ""
    @State private var serving = ""
    @State private var dose: Double = 1
    @State private var unit = "liều"
    @State private var timing = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sản phẩm") {
                    TextField("Tên (vd: Whey Gold Standard)", text: $name)
                    TextField("Thành phần, cách nhau bằng dấu phẩy", text: $ingredients, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Mô tả khẩu phần (vd: 1 scoop 30g)", text: $serving)
                }
                Section("Liều dùng") {
                    HStack {
                        Text("Mỗi ngày")
                        Spacer()
                        TextField("1", value: $dose, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        TextField("đơn vị", text: $unit).frame(width: 70)
                    }
                    TextField("Thời điểm (vd: sau tập)", text: $timing)
                }
            }
            .navigationTitle("Thêm supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") {
                        context.insert(Supplement(
                            name: name.trimmingCharacters(in: .whitespaces),
                            ingredients: ingredients,
                            servingDescription: serving,
                            dosagePerDay: dose,
                            unit: unit,
                            timingNote: timing
                        ))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
