import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Nguồn dữ liệu

struct HydrationEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetData.HydrationSnapshot
}

struct HydrationProvider: TimelineProvider {

    func placeholder(in context: Context) -> HydrationEntry {
        HydrationEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        completion(HydrationEntry(date: .now, snapshot: context.isPreview ? .placeholder : load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        let entry = HydrationEntry(date: .now, snapshot: load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> WidgetData.HydrationSnapshot {
        let container = SharedStore.makeContainer()
        return WidgetData.hydration(context: ModelContext(container))
    }
}

// MARK: - Giao diện

struct HydrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: HydrationEntry

    /// Bốn mức rót nhanh: ly nhỏ, lon, chai thường, chai lớn.
    static let quickAmounts: [Double] = [200, 330, 500, 750]

    private var s: WidgetData.HydrationSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemSmall: smallBody
        default: mediumBody
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .font(.caption2.weight(.bold))
            Text("Nước")
                .font(.caption2.weight(.semibold))
            Spacer()
            if !s.seasonNote.isEmpty {
                Text(s.seasonNote)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(WidgetPalette.faint)
    }

    private var amountLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(format(s.consumedML))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(s.isOver ? WidgetPalette.over : WidgetPalette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("/ \(format(s.targetML))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(WidgetPalette.faint)
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            Spacer(minLength: 0)
            amountLine
            WidgetBar(progress: s.progress, height: 7, isOver: s.isOver)
            Text(statusLine)
                .font(.system(size: 10))
                .foregroundStyle(s.isOver ? WidgetPalette.over : WidgetPalette.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Chỉ đủ chỗ cho hai mức hay dùng nhất ở cỡ nhỏ.
            HStack(spacing: 5) {
                ForEach([200.0, 500.0], id: \.self) { amount in
                    waterButton(amount, compact: true)
                }
            }
        }
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            header

            HStack(alignment: .bottom) {
                amountLine
                Spacer()
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(s.isOver ? WidgetPalette.over : WidgetPalette.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            WidgetBar(progress: s.progress, height: 9, isOver: s.isOver)

            HStack(spacing: 6) {
                ForEach(Self.quickAmounts, id: \.self) { amount in
                    waterButton(amount, compact: false)
                }

                Button(intent: UndoLastWaterIntent()) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption2.weight(.semibold))
                        .frame(width: 26, height: 30)
                        .background(WidgetPalette.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func waterButton(_ amount: Double, compact: Bool) -> some View {
        Button(intent: AddWaterIntent(milliliters: amount)) {
            VStack(spacing: 0) {
                Text("+\(Int(amount))")
                    .font(.system(size: compact ? 11 : 12, weight: .bold).monospacedDigit())
                Text("ml")
                    .font(.system(size: 8))
                    .foregroundStyle(WidgetPalette.faint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 26 : 30)
            .background(WidgetPalette.ink.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func format(_ ml: Double) -> String {
        ml >= 1000 ? String(format: "%.1f L", ml / 1000) : "\(Int(ml)) ml"
    }

    private var statusLine: String {
        // Đạt mục tiêu là đủ; màu đỏ lại là chuyện khác, chỉ bật khi vượt hẳn 1 lít.
        if s.remaining <= 0 { return "Đã đủ nước hôm nay" }
        return "Còn \(format(s.remaining))"
    }
}

// MARK: - Widget

struct HydrationWidget: Widget {
    let kind = "MufitHydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydrationProvider()) { entry in
            HydrationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tiến độ uống nước")
        .description("Lượng nước đã uống so với nhu cầu, thêm nước ngay trên widget.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
