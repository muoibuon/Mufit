import SwiftUI
import SwiftData
import Charts

struct BodyView: View {
    @Environment(\.modelContext) private var context

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var showAdd = false
    @State private var showConditions = false
    @State private var showGuidance = false

    private var profile: UserProfile? { profiles.first }
    private var latest: BodyMeasurement? { measurements.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let profile {
                        WeeklyMuscleMapView(profile: profile, measurement: latest)
                        if let latest {
                            compositionCard(profile, latest)
                            trendCard()
                            chartCard()
                        } else {
                            Card(title: "Chưa có số đo", systemImage: "scalemass") {
                                EmptyStateView(
                                    systemImage: "figure.stand",
                                    title: "Bắt đầu bằng một lần cân",
                                    message: "Nhập cân nặng, và nếu có thì % mỡ, khối cơ, tỉ lệ nước. Có % mỡ thì app tính BMR bằng công thức Katch-McArdle, chính xác hơn hẳn."
                                )
                                Button { showAdd = true } label: {
                                    Label("Nhập số đo đầu tiên", systemImage: "plus.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ProminentActionStyle())
                            }
                        }
                        conditionsCard(profile)
                        historyCard()
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Cơ thể")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddMeasurementView() }
            .sheet(isPresented: $showConditions) { ConditionsView() }
            .sheet(isPresented: $showGuidance) { ConditionGuidanceView() }
        }
    }

    private func compositionCard(_ profile: UserProfile, _ m: BodyMeasurement) -> some View {
        let bmi = BodyCompositionAnalyzer.bmi(weightKg: m.weightKg, heightCm: profile.heightCm)
        let rfm = m.bodyFatPercent == nil && m.waistCm != nil
            ? BodyCompositionAnalyzer.relativeFatMass(heightCm: profile.heightCm, waistCm: m.waistCm!, sex: profile.sex)
            : nil
        let bf = m.bodyFatPercent ?? rfm

        return Card(title: "Thành phần cơ thể", systemImage: "figure.stand") {
            HStack(spacing: 10) {
                StatTile(value: String(format: "%.1f", m.weightKg), unit: "kg", caption: "Cân nặng", systemImage: "scalemass")
                StatTile(
                    value: bf.map { String(format: "%.1f", $0) } ?? "—",
                    unit: bf == nil ? nil : "%",
                    caption: bf == nil ? "Mỡ cơ thể" : BodyCompositionAnalyzer.fatCategory(bodyFatPercent: bf!, sex: profile.sex).label,
                    systemImage: "drop.triangle"
                )
                StatTile(value: String(format: "%.1f", bmi), caption: BodyCompositionAnalyzer.bmiCategoryAsian(bmi), systemImage: "ruler")
            }

            if let lean = m.leanMassKg {
                HStack(spacing: 10) {
                    StatTile(value: String(format: "%.1f", lean), unit: "kg", caption: "Khối nạc", systemImage: "figure.arms.open")
                    if let fat = m.fatMassKg {
                        StatTile(value: String(format: "%.1f", fat), unit: "kg", caption: "Khối mỡ", systemImage: "circle.hexagongrid.fill")
                    }
                    StatTile(
                        value: Fmt.int(EnergyCalculator.bmrKatchMcArdle(leanMassKg: lean)),
                        unit: "kcal",
                        caption: "BMR (Katch-McArdle)",
                        systemImage: "bed.double.fill"
                    )
                }
            }

            if rfm != nil {
                Text("Chưa có số đo % mỡ, app ước lượng từ vòng eo bằng công thức RFM (Woolcott & Bergman 2018).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let w = m.bodyWaterPercent {
                Label(BodyCompositionAnalyzer.waterStatus(percent: w, sex: profile.sex), systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let v = m.visceralFatRating {
                Label(BodyCompositionAnalyzer.visceralStatus(rating: v), systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func trendCard() -> some View {
        Card(title: "Xu hướng 30 ngày", systemImage: "chart.line.uptrend.xyaxis") {
            if let t = BodyCompositionAnalyzer.trend(measurements: measurements) {
                HStack(spacing: 10) {
                    StatTile(value: String(format: "%+.1f", t.weightDeltaKg), unit: "kg", caption: "Cân nặng", systemImage: "scalemass",
                             tint: t.weightDeltaKg < 0 ? IconPalette.training : IconPalette.energy)
                    if let f = t.fatDeltaKg {
                        StatTile(value: String(format: "%+.1f", f), unit: "kg", caption: "Mỡ", systemImage: "drop.triangle",
                                 tint: f < 0 ? IconPalette.training : AlertPalette.over)
                    }
                    if let l = t.leanDeltaKg {
                        StatTile(value: String(format: "%+.1f", l), unit: "kg", caption: "Cơ nạc", systemImage: "figure.arms.open",
                                 tint: l > 0 ? IconPalette.training : AlertPalette.over)
                    }
                }
                Text(t.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Cần ít nhất 2 lần đo trong 30 ngày để tính xu hướng.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chartCard() -> some View {
        let data = measurements.sorted { $0.date < $1.date }.suffix(30)
        return Card(title: "Biểu đồ", systemImage: "chart.xyaxis.line") {
            Chart {
                ForEach(Array(data)) { m in
                    LineMark(
                        x: .value("Ngày", m.date),
                        y: .value("Cân nặng", m.weightKg),
                        series: .value("Chỉ số", "Cân nặng")
                    )
                    .foregroundStyle(Color.brand)
                    .symbol(.circle)
                }
                ForEach(Array(data.filter { $0.bodyFatPercent != nil })) { m in
                    LineMark(
                        x: .value("Ngày", m.date),
                        y: .value("Mỡ", m.weightKg * (m.bodyFatPercent ?? 0) / 100),
                        series: .value("Chỉ số", "Khối mỡ")
                    )
                    .foregroundStyle(Color.brandWarm)
                    .symbol(.square)
                }
            }
            .chartForegroundStyleScale([
                "Cân nặng": Color.brand,
                "Khối mỡ": Color.brandWarm
            ])
            .frame(height: 200)
        }
    }

    private func conditionsCard(_ profile: UserProfile) -> some View {
        Card(title: "Bệnh nền & gợi ý tập", systemImage: "cross.case.fill") {
            if profile.conditions.isEmpty {
                Text("Chưa khai báo bệnh nền nào. Khai báo để app điều chỉnh gợi ý bài tập và cảnh báo an toàn.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                FlowChips(items: profile.conditions.map(\.label))
                ForEach(ConditionAdvisor.allGuidance(for: profile.conditions).prefix(2)) { g in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(g.condition.label).font(.subheadline.weight(.semibold))
                        Text(g.summary).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
            }

            Button {
                // Đã khai báo thì mở phần xem gợi ý; chưa có gì thì mới vào màn khai báo.
                if profile.conditions.isEmpty {
                    showConditions = true
                } else {
                    showGuidance = true
                }
            } label: {
                Label(profile.conditions.isEmpty ? "Khai báo bệnh nền" : "Xem chi tiết gợi ý",
                      systemImage: profile.conditions.isEmpty ? "plus.circle" : "chevron.right.circle")
                    .font(.subheadline)
            }
        }
    }

    private func historyCard() -> some View {
        Card(title: "Lịch sử đo", systemImage: "clock.arrow.circlepath") {
            if measurements.isEmpty {
                Text("Chưa có dữ liệu.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(measurements.prefix(8)) { m in
                HStack {
                    Text(Fmt.dayMonth.string(from: m.date))
                        .font(.caption.monospacedDigit())
                        .frame(width: 44, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(Fmt.kg(m.weightKg)).font(.subheadline.monospacedDigit())
                    if let bf = m.bodyFatPercent {
                        Text("· \(Fmt.percent(bf)) mỡ").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        context.delete(m)
                        try? context.save()
                    } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 1)
            }
        }
    }
}
