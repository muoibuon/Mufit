import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Nguồn dữ liệu

struct NutritionEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetData.NutritionSnapshot
}

struct NutritionProvider: TimelineProvider {

    func placeholder(in context: Context) -> NutritionEntry {
        NutritionEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NutritionEntry) -> Void) {
        completion(NutritionEntry(date: .now, snapshot: context.isPreview ? .placeholder : load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutritionEntry>) -> Void) {
        let entry = NutritionEntry(date: .now, snapshot: load())
        // Làm mới mỗi 15 phút; ngoài ra app chủ động gọi reload mỗi khi ghi bữa ăn.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> WidgetData.NutritionSnapshot {
        let container = SharedStore.makeContainer()
        return WidgetData.nutrition(context: ModelContext(container))
    }
}

// MARK: - Giao diện

struct NutritionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NutritionEntry

    private var s: WidgetData.NutritionSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemSmall: smallBody
        default: mediumBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "fork.knife")
                    .font(.caption2.weight(.bold))
                Text("Ăn uống")
                    .font(.caption2.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(WidgetPalette.faint)

            ZStack {
                WidgetRing(progress: s.progress, lineWidth: 8)
                VStack(spacing: -1) {
                    Text("\(Int(s.consumedCalories))")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(s.isOver ? WidgetPalette.over : WidgetPalette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/ \(Int(s.targetCalories))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(WidgetPalette.faint)
                }
            }
            .frame(maxWidth: .infinity)

            Text(statusLine)
                .font(.caption2)
                .foregroundStyle(s.isOver ? WidgetPalette.over : WidgetPalette.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .widgetURL(URL(string: "fitcore://addmeal"))
    }

    private var mediumBody: some View {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                ZStack {
                    WidgetRing(progress: s.progress, lineWidth: 9)
                    VStack(spacing: -2) {
                        Text("\(Int(s.consumedCalories))")
                            .font(.headline.bold().monospacedDigit())
                            .foregroundStyle(s.isOver ? WidgetPalette.over : WidgetPalette.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("kcal")
                            .font(.system(size: 9))
                            .foregroundStyle(WidgetPalette.faint)
                    }
                }
                .frame(width: 72, height: 72)

                Text("\(s.mealCount) bữa")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.faint)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(statusLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(s.isOver ? WidgetPalette.over : WidgetPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                macroRow("Đạm", s.protein, s.proteinTarget)
                macroRow("Carb", s.carbs, s.carbsTarget)
                macroRow("Béo", s.fat, s.fatTarget)

                Link(destination: URL(string: "fitcore://addmeal")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Thêm bữa")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WidgetPalette.ink.opacity(0.14), in: Capsule())
                }
                .padding(.top, 1)
            }
        }
    }

    private func macroRow(_ label: String, _ value: Double, _ target: Double) -> some View {
        let ratio = target > 0 ? value / target : 0
        let over = ratio > 1.15
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(over ? WidgetPalette.over : WidgetPalette.ink)
                Spacer()
                Text("\(Int(value))/\(Int(target))")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(over ? WidgetPalette.over : WidgetPalette.faint)
            }
            WidgetBar(progress: ratio, height: 4, isOver: over)
        }
    }

    private var statusLine: String {
        if s.isOver {
            return "Vượt \(Int(s.consumedCalories - s.targetCalories)) kcal"
        }
        return "Còn \(Int(s.remaining)) kcal"
    }
}

// MARK: - Widget

struct NutritionWidget: Widget {
    let kind = "MufitNutritionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionProvider()) { entry in
            NutritionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tiến độ ăn uống")
        .description("Calo và macro đã nạp hôm nay, kèm lối tắt thêm bữa.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
