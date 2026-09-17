import SwiftUI
import SwiftData

/// Tìm món ăn trong thư viện cục bộ, hoặc tra cứu online trên Open Food Facts.
struct FoodSearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var catalog: CatalogStore

    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    var onPick: (FoodItem) -> Void

    @State private var search = ""
    @State private var onlineResults: [FoodItem] = []
    @State private var showCustom = false

    private var local: [FoodItem] {
        guard !search.isEmpty else { return Array(foods.prefix(40)) }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Thư viện của bạn (\(local.count))") {
                    if local.isEmpty {
                        Text("Không có món nào khớp.").font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(local) { f in foodRow(f) }
                }

                if !onlineResults.isEmpty {
                    Section("Kết quả từ Open Food Facts") {
                        ForEach(onlineResults) { f in foodRow(f) }
                    }
                }

                Section {
                    Button {
                        Task {
                            onlineResults = await catalog.searchAndImportFoods(term: search, context: context)
                        }
                    } label: {
                        if case .syncing(let m) = catalog.foodSearchState {
                            HStack { ProgressView(); Text(m).font(.footnote) }
                        } else {
                            Label("Tra cứu online \"\(search)\"", systemImage: "globe")
                        }
                    }
                    .disabled(search.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button { showCustom = true } label: {
                        Label("Tự thêm món ăn", systemImage: "plus.circle")
                    }

                    switch catalog.foodSearchState {
                    case .failure(let m): Text(m).font(.caption).foregroundStyle(Color.brandRed)
                    case .success(let m): Text(m).font(.caption).foregroundStyle(Color.brandGreen)
                    default: EmptyView()
                    }
                } footer: {
                    Text("Thư viện offline dựa trên USDA FoodData Central và Bảng thành phần thực phẩm Việt Nam (Viện Dinh dưỡng). Kết quả online lấy từ Open Food Facts (ODbL) — số liệu từ nhãn sản phẩm, nên kiểm tra lại trước khi tin tuyệt đối.")
                        .font(.caption2)
                }
            }
            .searchable(text: $search, prompt: "Tìm món ăn")
            .navigationTitle("Chọn món")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Đóng") { dismiss() } }
            }
            .sheet(isPresented: $showCustom) {
                CustomFoodSheet { food in
                    onPick(food)
                    dismiss()
                }
            }
        }
    }

    private func foodRow(_ f: FoodItem) -> some View {
        Button {
            onPick(f)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(f.name).font(.subheadline.weight(.medium))
                Text("\(Int(f.caloriesPer100g)) kcal · P\(Int(f.proteinPer100g)) C\(Int(f.carbsPer100g)) F\(Int(f.fatPer100g)) / 100 gram")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !f.brand.isEmpty {
                    Text(f.brand).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CustomFoodSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var onCreate: (FoodItem) -> Void

    @State private var name = ""
    @State private var kcal: Double = 100
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double = 0

    /// Calo suy ra từ macro (4/4/9) để đối chiếu với số người dùng nhập.
    private var derivedKcal: Double { protein * 4 + carbs * 4 + fat * 9 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Món ăn") {
                    TextField("Tên món", text: $name)
                }
                Section {
                    field("Calo (kcal)", $kcal)
                    field("Đạm (gram)", $protein)
                    field("Carb (gram)", $carbs)
                    field("Béo (gram)", $fat)
                    field("Chất xơ (gram)", $fiber)
                } header: {
                    Text("Dinh dưỡng trên 100 gram")
                } footer: {
                    if derivedKcal > 0 && abs(derivedKcal - kcal) > 25 {
                        Text("Macro bạn nhập tương đương \(Int(derivedKcal)) kcal, lệch khá xa con số \(Int(kcal)) kcal. Kiểm tra lại.")
                            .font(.caption2)
                            .foregroundStyle(Color.brandWarm)
                    }
                }
            }
            .navigationTitle("Món của bạn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Thêm") {
                        let f = FoodItem(
                            slug: "custom-" + UUID().uuidString,
                            name: name.trimmingCharacters(in: .whitespaces),
                            caloriesPer100g: kcal,
                            proteinPer100g: protein,
                            carbsPer100g: carbs,
                            fatPer100g: fat,
                            fiberPer100g: fiber,
                            sourceName: "Tự thêm",
                            isCustom: true
                        )
                        context.insert(f)
                        try? context.save()
                        onCreate(f)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func field(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}
