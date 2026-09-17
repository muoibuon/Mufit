import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var router: AppRouter

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query private var supplements: [Supplement]

    @State private var selectedDate = Date().startOfDay
    @State private var showAddMeal = false
    /// Bữa đang sửa. Mở dạng sheet chứ không push, vì MealEditorView tự bọc
    /// NavigationStack riêng — push vào sẽ thành stack lồng nhau và nút Huỷ mất tác dụng.
    @State private var editingMeal: MealEntry?
    @State private var showSupplements = false

    private var dayMeals: [MealEntry] {
        meals.filter { $0.date.isSameDay(as: selectedDate) }
    }

    private var ctx: DayEnergyContext? {
        guard let profile = profiles.first else { return nil }
        return DayEnergyContext(
            profile: profile,
            latestMeasurement: measurements.first,
            weather: weatherStore.today,
            sessions: sessions.filter { $0.date.isSameDay(as: selectedDate) },
            meals: dayMeals
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dayPicker

                    if let ctx {
                        macroCard(ctx)
                        mealsCard(ctx)
                        gapCard(ctx)
                        supplementCard(ctx)
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Ăn uống")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddMeal = true } label: { Image(systemName: "plus") }
                }
            }
            .onChange(of: router.pendingAddMeal) { _, wants in
                if wants {
                    showAddMeal = true
                    router.pendingAddMeal = false
                }
            }
            .onAppear {
                if router.pendingAddMeal {
                    showAddMeal = true
                    router.pendingAddMeal = false
                }
            }
            .sheet(isPresented: $showAddMeal) {
                MealEditorView(date: selectedDate, meal: nil)
            }
            .sheet(item: $editingMeal) { meal in
                MealEditorView(date: selectedDate, meal: meal)
            }
            .sheet(isPresented: $showSupplements) {
                SupplementsView()
            }
        }
    }

    private var dayPicker: some View {
        HStack {
            Button { selectedDate = selectedDate.adding(days: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            VStack(spacing: 1) {
                Text(Fmt.fullDate.string(from: selectedDate).capitalized)
                    .font(.subheadline.weight(.semibold))
                if !selectedDate.isSameDay(as: .now) {
                    Button("Về hôm nay") { selectedDate = Date().startOfDay }
                        .font(.caption2)
                }
            }
            Spacer()
            Button { selectedDate = selectedDate.adding(days: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedDate >= Date().startOfDay)
        }
    }

    private func macroCard(_ ctx: DayEnergyContext) -> some View {
        let target = ctx.macroTarget
        let consumed = ctx.consumed

        return Card(title: "Macro hôm nay", systemImage: "chart.pie.fill") {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: target.calories > 0 ? consumed.calories / target.calories : 0, lineWidth: 11)
                    VStack(spacing: 0) {
                        Text(Fmt.int(consumed.calories))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(consumed.calories > target.calories ? AlertPalette.over : .primary)
                            .contentTransition(.numericText(value: consumed.calories))
                            .animation(.snappy, value: consumed.calories)
                        Text("kcal").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 88, height: 88)

                VStack(spacing: 8) {
                    MacroBar(label: "Đạm", consumed: consumed.protein, target: target.protein, unit: "gram", tint: .brand)
                    MacroBar(label: "Carb", consumed: consumed.carbs, target: target.carbs, unit: "gram", tint: .brand)
                    MacroBar(label: "Béo", consumed: consumed.fat, target: target.fat, unit: "gram", tint: .brand)
                }
            }

            Text("Mục tiêu \(Fmt.kcal(target.calories)) = TDEE \(Fmt.int(ctx.tdee)) + tập \(Fmt.int(ctx.workoutCalories)) \(ctx.profile.calorieOffsetRatio < 0 ? "−" : "+") \(abs(Int(ctx.profile.calorieOffsetRatio * 100)))% theo mục tiêu \(ctx.profile.goalSummary.lowercased()).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func mealsCard(_ ctx: DayEnergyContext) -> some View {
        Card(title: "Bữa ăn", systemImage: "fork.knife") {
            if dayMeals.isEmpty {
                EmptyStateView(
                    systemImage: "takeoutbag.and.cup.and.straw",
                    title: "Chưa ghi bữa nào",
                    message: "Thêm bữa ăn để app tính calo và macro theo số gram thật của từng món."
                )
            } else {
                ForEach(MealSlot.allCases) { slot in
                    let slotMeals = dayMeals.filter { $0.slot == slot }
                    if !slotMeals.isEmpty {
                        ForEach(slotMeals) { meal in
                            Button {
                                editingMeal = meal
                            } label: {
                                MealRow(meal: meal)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }

            Button { showAddMeal = true } label: {
                Label("Thêm bữa ăn", systemImage: "plus.circle.fill").font(.subheadline)
            }
        }
    }

    private func gapCard(_ ctx: DayEnergyContext) -> some View {
        let gaps = NutritionGapAdvisor.gaps(consumed: ctx.consumed, target: ctx.macroTarget)
        return Card(title: "Còn thiếu gì?", systemImage: "exclamationmark.bubble.fill") {
            ForEach(gaps.filter { $0.isDeficit || $0.isExcess }) { gap in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: gap.isDeficit ? "arrow.down.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(gap.isDeficit ? Color.brandWarm : AlertPalette.over)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(gap.nutrient): \(Int(gap.consumed))/\(Int(gap.target)) \(gap.unit)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(gap.isExcess ? AlertPalette.over : .primary)
                        Text(gap.suggestion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }

            if gaps.allSatisfy({ !$0.isDeficit && !$0.isExcess }) {
                Label("Mọi chỉ số đều nằm trong khoảng mục tiêu.", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.brandGreen)
            }
        }
    }

    private func supplementCard(_ ctx: DayEnergyContext) -> some View {
        let gaps = NutritionGapAdvisor.gaps(consumed: ctx.consumed, target: ctx.macroTarget)
        let suggestions = NutritionGapAdvisor.supplementSuggestions(
            gaps: gaps,
            existing: supplements.filter(\.isActive),
            conditions: ctx.profile.conditions
        )

        return Card(title: "Thực phẩm bổ sung", systemImage: "pills.fill") {
            let active = supplements.filter(\.isActive)
            if active.isEmpty {
                Text("Chưa khai báo supplement nào.").font(.footnote).foregroundStyle(.secondary)
            } else {
                FlowChips(items: active.map(\.name))
            }

            if !suggestions.isEmpty {
                Divider()
                Text("Gợi ý").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(suggestions, id: \.self) { s in
                    Text("• " + s)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button { showSupplements = true } label: {
                Label("Quản lý supplement", systemImage: "chevron.right.circle").font(.subheadline)
            }
        }
    }
}

struct MealRow: View {
    let meal: MealEntry

    var body: some View {
        let t = meal.totals
        return HStack {
            Image(systemName: meal.slot.systemImage)
                .foregroundStyle(IconPalette.energy)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.slot.label).font(.subheadline.weight(.medium))
                Text(meal.portions.compactMap { $0.food?.name }.prefix(3).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Fmt.kcal(t.calories)).font(.caption.weight(.semibold).monospacedDigit())
                Text("P\(Int(t.protein)) C\(Int(t.carbs)) F\(Int(t.fat))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }
}
