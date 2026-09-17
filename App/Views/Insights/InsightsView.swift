import SwiftUI
import SwiftData
import Charts

/// Phân tích tổng hợp: cân đối nhóm cơ, hiệu suất, cân bằng năng lượng theo tuần.
struct InsightsView: View {
    @EnvironmentObject private var weatherStore: WeatherStore

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]

    @State private var window = 14

    private var profile: UserProfile? { profiles.first }
    private var bodyWeight: Double { measurements.first?.weightKg ?? 70 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    windowPicker
                    alertsCard
                    performanceCard
                    muscleVolumeCard
                    energyTrendCard
                    if let p = profile { sourcesCard(p) }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Phân tích")
        }
    }

    private var windowPicker: some View {
        Picker("Khoảng thời gian", selection: $window) {
            Text("7 ngày").tag(7)
            Text("14 ngày").tag(14)
            Text("30 ngày").tag(30)
        }
        .pickerStyle(.segmented)
    }

    private var alertsCard: some View {
        Card(title: "Cảnh báo nhóm cơ", systemImage: "exclamationmark.triangle.fill") {
            let alerts = MuscleBalanceAnalyzer.alerts(sessions: sessions, days: window)
            ForEach(alerts) { a in
                AlertRow(alert: a)
                if a.id != alerts.last?.id { Divider() }
            }
        }
    }

    private var performanceCard: some View {
        let completed = completedSessions
        let rate = MuscleBalanceAnalyzer.averageCompletionRate(sessions: sessions, days: window)
        let totalVolume = completed.reduce(0) { $0 + $1.completedVolumeKg }
        let totalCalories = completed.reduce(0) {
            $0 + EnergyCalculator.caloriesForSession($1, bodyWeightKg: bodyWeight, weather: weatherStore.today)
        }

        return Card(title: "Hiệu suất tập", systemImage: "speedometer") {
            HStack(spacing: 10) {
                StatTile(value: "\(completed.count)", caption: "Buổi xong", systemImage: "checkmark.circle")
                StatTile(value: "\(Int(rate * 100))", unit: "%", caption: "Hiệu suất", systemImage: "target",
                         tint: rate >= 0.9 ? IconPalette.training : (rate >= 0.7 ? IconPalette.energy : AlertPalette.over))
                StatTile(value: Fmt.int(totalVolume), unit: "kg", caption: "Khối lượng", systemImage: "scalemass")
                StatTile(value: Fmt.int(totalCalories), unit: "kcal", caption: "Đã đốt", systemImage: "flame.fill")
            }

            let daily = dailyPerformance
            if !daily.isEmpty {
                Chart(daily, id: \.date) { d in
                    BarMark(
                        x: .value("Ngày", d.date, unit: .day),
                        y: .value("Hiệu suất", min(d.rate, 1.2) * 100)
                    )
                    .foregroundStyle(d.rate >= 0.9 ? Color.brandGreen : (d.rate >= 0.7 ? Color.brandWarm : Color.brandRed))
                    .cornerRadius(3)
                }
                .chartYScale(domain: 0...120)
                .chartYAxisLabel("% hiệu suất")
                .frame(height: 150)
                .clipped()
            }

            Text(performanceNote(rate: rate, count: completed.count))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func performanceNote(rate: Double, count: Int) -> String {
        guard count > 0 else { return "Chưa có buổi tập nào hoàn thành trong \(window) ngày qua." }
        let perWeek = Double(count) / (Double(window) / 7)
        var s = "Trung bình \(String(format: "%.1f", perWeek)) buổi/tuần. "
        if rate >= 0.95 {
            s += "Bạn đang hoàn thành gần hết kế hoạch — đã đến lúc tăng tải (thêm 2.5-5% tạ hoặc 1 rep/set)."
        } else if rate >= 0.8 {
            s += "Hiệu suất ổn. Giữ mức tải hiện tại thêm 1-2 tuần trước khi tăng."
        } else {
            s += "Hiệu suất thấp kéo dài thường là dấu hiệu tải quá nặng, thiếu ngủ hoặc thâm hụt calo quá sâu."
        }
        return s
    }

    private var muscleVolumeCard: some View {
        let stats = MuscleBalanceAnalyzer.stats(sessions: sessions, days: window)
            .filter { $0.totalSets > 0 || $0.muscle.isMajor }
            .sorted { $0.volumeKg > $1.volumeKg }

        return Card(title: "Khối lượng theo nhóm cơ", systemImage: "chart.bar.fill") {
            if stats.allSatisfy({ $0.volumeKg == 0 }) {
                Text("Chưa có dữ liệu khối lượng trong \(window) ngày qua.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart(stats) { s in
                    BarMark(
                        x: .value("Khối lượng", s.volumeKg),
                        y: .value("Nhóm cơ", s.muscle.label)
                    )
                    .foregroundStyle(s.sessionCount == 0 && s.muscle.isMajor ? Color.brandRed : Color.brand)
                    .cornerRadius(3)
                }
                .frame(height: CGFloat(stats.count) * 22 + 20)

                Text("Cột đỏ = nhóm cơ lớn chưa được tập buổi nào. Nhóm cơ phụ được tính 40% khối lượng của bài.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var energyTrendCard: some View {
        Card(title: "Cân bằng năng lượng theo ngày", systemImage: "flame.circle.fill") {
            let points = energyPoints
            if points.isEmpty {
                Text("Chưa đủ dữ liệu ăn uống để vẽ biểu đồ.").font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart(points, id: \.date) { p in
                    BarMark(
                        x: .value("Ngày", p.date, unit: .day),
                        y: .value("Chênh lệch", p.balance)
                    )
                    .foregroundStyle(p.balance < 0 ? Color.brandGreen : Color.brandWarm)
                    .cornerRadius(3)
                }
                .chartYAxisLabel("kcal (âm = thâm hụt)")
                .frame(height: 160)

                let avg = points.reduce(0) { $0 + $1.balance } / Double(points.count)
                let weeklyKg = avg * 7 / 7700   // 1 kg mỡ ≈ 7700 kcal
                Text("Trung bình \(Int(avg)) kcal/ngày so với mức duy trì → tương đương \(String(format: "%+.2f", weeklyKg)) kg mỡ mỗi tuần nếu giữ nguyên nhịp này.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourcesCard(_ p: UserProfile) -> some View {
        Card(title: "Nguồn dữ liệu & công thức", systemImage: "book.closed.fill") {
            VStack(alignment: .leading, spacing: 6) {
                source("BMR", "Mifflin-St Jeor (Am J Clin Nutr 1990) và Katch-McArdle khi có % mỡ")
                source("Calo bài tập", "MET — Compendium of Physical Activities, Ainsworth 2011")
                source("% mỡ ước lượng", "RFM — Woolcott & Bergman, Scientific Reports 2018")
                source("Nhu cầu nước", "EFSA 2010 + ACSM bù nước khi vận động")
                source("Vitamin D", "Holick, N Engl J Med 2007; Endocrine Society")
                source("Tần suất nhóm cơ", "ACSM Position Stand 2011 — tối thiểu 2 buổi/tuần mỗi nhóm cơ lớn")
                source("Thư viện bài tập", "wger.de (CC-BY-SA) + bộ offline đóng gói sẵn")
                source("Dữ liệu thực phẩm", "USDA FoodData Central, Viện Dinh dưỡng VN, Open Food Facts (ODbL)")
                source("Thời tiết & UV", "Open-Meteo (mô hình ICON/GFS)")
            }
            Divider()
            Text(ConditionAdvisor.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func source(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption.weight(.semibold))
                Text(value).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Dữ liệu dẫn xuất

    private var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -window, to: .now) ?? .now
    }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.date >= cutoff && $0.status == .completed }
    }

    struct DayPerformance {
        var date: Date
        var rate: Double
    }

    /// Một ngày có thể có nhiều buổi tập. Gộp chung reps của cả ngày rồi mới chia,
    /// thay vì vẽ từng buổi một — nếu không các cột cùng ngày sẽ cộng dồn lên nhau.
    private var dailyPerformance: [DayPerformance] {
        let grouped = Dictionary(grouping: completedSessions) { $0.date.startOfDay }
        return grouped.compactMap { day, daySessions -> DayPerformance? in
            let planned = daySessions.reduce(0) { $0 + $1.plannedRepTotal }
            guard planned > 0 else { return nil }
            let actual = daySessions.reduce(0) { $0 + $1.actualRepTotal }
            return DayPerformance(date: day, rate: Double(actual) / Double(planned))
        }
        .sorted { $0.date < $1.date }
    }

    private struct EnergyPoint {
        var date: Date
        var balance: Double
    }

    private var energyPoints: [EnergyPoint] {
        guard let profile else { return [] }
        var out: [EnergyPoint] = []

        for offset in stride(from: window - 1, through: 0, by: -1) {
            let day = Date().adding(days: -offset).startOfDay
            let dayMeals = meals.filter { $0.date.isSameDay(as: day) }
            guard !dayMeals.isEmpty else { continue }

            let ctx = DayEnergyContext(
                profile: profile,
                latestMeasurement: measurements.first { $0.date <= day.endOfDay } ?? measurements.first,
                weather: weatherStore.today,
                sessions: sessions.filter { $0.date.isSameDay(as: day) },
                meals: dayMeals
            )
            out.append(EnergyPoint(date: day, balance: ctx.energyBalance))
        }
        return out
    }
}
