import SwiftUI
import SwiftData

/// Soạn một bữa ăn: thêm món, nhập số gram, xem tổng hợp calo/macro ngay.
struct MealEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var date: Date
    var meal: MealEntry?

    @State private var slot: MealSlot = .breakfast
    @State private var note: String = ""
    @State private var entries: [PortionDraft] = []
    @State private var showFoodSearch = false

    struct PortionDraft: Identifiable {
        var id = UUID()
        var food: FoodItem
        var grams: Double
    }

    private var totals: MacroTotals {
        entries.reduce(.zero) { acc, e in
            let k = e.grams / 100
            return acc + MacroTotals(
                calories: e.food.caloriesPer100g * k,
                protein: e.food.proteinPer100g * k,
                carbs: e.food.carbsPer100g * k,
                fat: e.food.fatPer100g * k,
                fiber: e.food.fiberPer100g * k,
                sodiumMg: e.food.sodiumMgPer100g * k,
                sugar: e.food.sugarPer100g * k
            )
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bữa") {
                    Picker("Loại bữa", selection: $slot) {
                        ForEach(MealSlot.allCases) { s in
                            Label(s.label, systemImage: s.systemImage).tag(s)
                        }
                    }
                    TextField("Ghi chú", text: $note)
                }

                Section {
                    HStack(spacing: 10) {
                        StatTile(value: Fmt.int(totals.calories), unit: "kcal", caption: "Năng lượng", systemImage: "flame.fill")
                        StatTile(value: Fmt.int(totals.protein), unit: "g", caption: "Đạm", systemImage: "fish.fill")
                        StatTile(value: Fmt.int(totals.carbs), unit: "g", caption: "Carb", systemImage: "bolt.fill")
                        StatTile(value: Fmt.int(totals.fat), unit: "g", caption: "Béo", systemImage: "oilcan.fill")
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                }

                Section("Món ăn (tính theo gram)") {
                    if entries.isEmpty {
                        Text("Chưa có món nào.").font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach($entries) { $entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.food.name).font(.subheadline.weight(.medium))
                                    Text("\(Int(entry.food.caloriesPer100g)) kcal/100 gram · \(entry.food.sourceName)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(Fmt.kcal(entry.food.caloriesPer100g * entry.grams / 100))
                                    .font(.caption.weight(.semibold).monospacedDigit())
                            }
                            HStack(spacing: 8) {
                                Slider(value: $entry.grams, in: 5...600, step: 5)
                                TextField("g", value: $entry.grams, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 56)
                                Text("gram").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { entries.remove(atOffsets: $0) }

                    Button {
                        showFoodSearch = true
                    } label: {
                        Label("Thêm món", systemImage: "plus.circle.fill")
                    }
                }

                if let m = meal {
                    Section {
                        Button(role: .destructive) {
                            context.delete(m)
                            try? context.save()
                            WidgetRefresh.reload()
                            dismiss()
                        } label: {
                            Label("Xoá bữa này", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(meal == nil ? "Thêm bữa ăn" : "Sửa bữa ăn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") { save() }.disabled(entries.isEmpty)
                }
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView { food in
                    entries.append(PortionDraft(food: food, grams: 100))
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let m = meal else { return }
        slot = m.slot
        note = m.note
        entries = m.portions.compactMap { p in
            guard let f = p.food else { return nil }
            return PortionDraft(food: f, grams: p.grams)
        }
    }

    private func save() {
        let target: MealEntry
        if let m = meal {
            target = m
            for p in m.portions { context.delete(p) }
            target.portions.removeAll()
        } else {
            // Giữ giờ hiện tại nhưng gán đúng ngày đang xem.
            let comps = Calendar.current.dateComponents([.hour, .minute], from: .now)
            let d = Calendar.current.date(bySettingHour: comps.hour ?? 12, minute: comps.minute ?? 0, second: 0, of: date) ?? date
            target = MealEntry(date: d, slot: slot, note: note)
            context.insert(target)
        }

        target.slot = slot
        target.note = note

        for e in entries {
            let portion = FoodPortion(grams: e.grams, food: e.food)
            portion.meal = target
            context.insert(portion)
        }

        try? context.save()
        WidgetRefresh.reload()
        dismiss()
    }
}
