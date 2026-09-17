import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var location: LocationActivityService
    @EnvironmentObject private var router: AppRouter

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query private var hydration: [HydrationLog]
    @Query private var sunLogs: [SunExposureLog]

    @State private var showSunSheet = false
    @State private var showSettings = false
    @State private var showMore = false

    private var profile: UserProfile? { profiles.first }

    private var todaySessions: [WorkoutSession] {
        sessions.filter { $0.date.isSameDay(as: .now) }
    }

    private var nextSession: WorkoutSession? {
        todaySessions.first { $0.status == .inProgress }
            ?? todaySessions.first { $0.status == .planned }
    }

    private var ctx: DayEnergyContext? {
        guard let profile else { return nil }
        return DayEnergyContext(
            profile: profile,
            latestMeasurement: measurements.first,
            weather: weatherStore.today,
            sessions: todaySessions,
            meals: meals.filter { $0.date.isSameDay(as: .now) }
        )
    }

    private var waterToday: Double {
        hydration.filter { $0.date.isSameDay(as: .now) }.reduce(0) { $0 + $1.milliliters }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let ctx {
                        headerCard(ctx)
                        actionCard(ctx)
                        energyCard(ctx)
                        hydrationCard(ctx)
                        DisclosureGroup(isExpanded: $showMore) {
                            VStack(spacing: 16) {
                                StreakCard(result: StreakCalculator.evaluate(sessions: sessions))
                                weatherCard(ctx)
                                sunCard()
                                adviceCard(ctx)
                            }
                            .padding(.top, 12)
                        } label: {
                            Label("Thông tin thêm", systemImage: "square.grid.2x2")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(16)
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Hôm nay")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showSunSheet) { SunExposureSheet() }
            .refreshable {
                await weatherStore.refresh(
                    context: context,
                    coordinate: location.currentLocation?.coordinate,
                    force: true
                )
            }
            .onAppear {
                if location.authorizationStatus == .notDetermined {
                    location.requestPermission()
                } else {
                    location.start()
                }
            }
        }
    }

    // MARK: - Các thẻ

    private func headerCard(_ ctx: DayEnergyContext) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Fmt.fullDate.string(from: .now).capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Mục tiêu: \(ctx.profile.goalSummary) · \(Fmt.kcal(ctx.calorieTarget))/ngày")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weatherCard(_ ctx: DayEnergyContext) -> some View {
        Card(title: "Thời tiết & mùa", systemImage: weatherStore.today?.season.systemImage ?? "cloud.fill") {
            if let w = weatherStore.today {
                HStack(spacing: 12) {
                    StatTile(value: "\(Int(w.meanTempC))", unit: "°C", caption: w.season.label, systemImage: w.season.systemImage)
                    StatTile(value: "\(Int(w.humidityPercent))", unit: "%", caption: "Độ ẩm", systemImage: "humidity.fill")
                    StatTile(value: String(format: "%.1f", w.uvIndexMax), caption: "UV tối đa", systemImage: "sun.max.trianglebadge.exclamationmark")
                }
            } else if weatherStore.isLoading {
                ProgressView("Đang lấy thời tiết…").font(.footnote)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(weatherStore.errorMessage ?? "Chưa có dữ liệu thời tiết.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Thử lại") {
                        Task {
                            await weatherStore.refresh(
                                context: context,
                                coordinate: location.currentLocation?.coordinate,
                                force: true
                            )
                        }
                    }
                    .font(.footnote)
                }
            }
        }
    }

    private func energyCard(_ ctx: DayEnergyContext) -> some View {
        Card(title: "Cân bằng năng lượng", systemImage: "flame.fill") {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: ctx.calorieTarget > 0 ? ctx.consumed.calories / ctx.calorieTarget : 0, lineWidth: 12)
                    VStack(spacing: 0) {
                        Text(Fmt.int(ctx.consumed.calories))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(ctx.consumed.calories > ctx.calorieTarget ? AlertPalette.over : .primary)
                            .contentTransition(.numericText(value: ctx.consumed.calories))
                            .animation(.snappy, value: ctx.consumed.calories)
                        Text("/ \(Fmt.int(ctx.calorieTarget))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Đã nạp hôm nay")
                        .font(.subheadline.weight(.semibold))
                    Text("Mục tiêu \(Fmt.kcal(ctx.calorieTarget))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            DisclosureGroup("Xem cách tính") {
                VStack(spacing: 8) {
                    row("Chuyển hoá nghỉ", Fmt.kcal(ctx.restingEnergy), "bed.double.fill")
                    row("TDEE (đã tính mùa)", Fmt.kcal(ctx.tdee), "figure.walk")
                    row("Đốt khi tập", Fmt.kcal(ctx.workoutCalories), "dumbbell.fill")
                    row("Nạp vào", Fmt.kcal(ctx.consumed.calories), "fork.knife")
                }
                .padding(.top, 8)
            }
            .font(.caption)

            Divider()
            balanceRow(ctx)
        }
    }

    /// Dòng tổng kết dưới thẻ cân bằng năng lượng.
    ///
    /// Con số thâm hụt chỉ có nghĩa khi ngày đã trôi qua phần lớn, hoặc khi đã ăn
    /// gần đủ mục tiêu. Mới 8 giờ sáng chưa ăn gì mà báo "đang thâm hụt 3000 kcal"
    /// thì vừa vô nghĩa vừa gây lo lắng — lúc đó việc cần làm là ghi bữa ăn.
    @ViewBuilder
    private func balanceRow(_ ctx: DayEnergyContext) -> some View {
        let balance = ctx.energyBalance
        let ratio = ctx.calorieTarget > 0 ? ctx.consumed.calories / ctx.calorieTarget : 0
        let hour = Calendar.current.component(.hour, from: .now)
        let deficitIsMeaningful = hour >= 20 || ratio >= 0.85

        if balance >= 0 {
            summaryLine("arrow.up.circle.fill", "Đang dư \(Fmt.kcal(balance))", IconPalette.energy)
        } else if deficitIsMeaningful {
            summaryLine("arrow.down.circle.fill", "Đang thâm hụt \(Fmt.kcal(-balance))", IconPalette.training)
        } else {
            summaryLine("clock", "Cân bằng ngày sẽ rõ hơn vào cuối ngày", IconPalette.energy)
        }
    }

    private func summaryLine(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private func actionCard(_ ctx: DayEnergyContext) -> some View {
        Card(title: "Việc hôm nay", systemImage: "checklist") {
            if let nextSession {
                NavigationLink {
                    ActiveSessionView(session: nextSession)
                } label: {
                    Label(nextSession.status == .inProgress ? "Tiếp tục buổi tập" : "Mở buổi tập hôm nay",
                          systemImage: nextSession.status == .inProgress ? "play.fill" : "dumbbell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProminentActionStyle())
                Text(nextSession.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    router.selectedTab = .nutrition
                    router.pendingAddMeal = true
                } label: {
                    Label("Ghi bữa ăn", systemImage: "fork.knife")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    router.selectedTab = .nutrition
                    router.pendingAddMeal = true
                } label: {
                    Label("Ghi bữa ăn", systemImage: "fork.knife")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProminentActionStyle())
                NavigationLink {
                    SessionBuilderView(date: .now)
                } label: {
                    Label("Tạo buổi tập", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            ForEach(todaySessions.filter { $0.id != nextSession?.id }) { session in
                NavigationLink {
                    ActiveSessionView(session: session)
                } label: {
                    SessionRow(session: session, calories: EnergyCalculator.caloriesForSession(
                        session, bodyWeightKg: ctx.bodyWeight, weather: ctx.weather))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hydrationCard(_ ctx: DayEnergyContext) -> some View {
        let rec = HydrationAdvisor.recommend(
            weightKg: ctx.bodyWeight,
            sex: ctx.profile.sex,
            trainingMinutes: ctx.trainingMinutes,
            weather: ctx.weather
        )
        return Card(title: "Nước", systemImage: "drop.fill") {
            MacroBar(label: "Đã uống", consumed: waterToday, target: rec.totalML,
                     unit: "ml", tint: IconPalette.water,
                     // Uống dư vài trăm ml là chuyện bình thường và vô hại,
                     // nên chỉ cảnh báo khi vượt hẳn 1 lít.
                     overAllowance: 1000)

            HStack(spacing: 8) {
                ForEach([200.0, 330.0, 500.0], id: \.self) { amount in
                    Button {
                        context.insert(HydrationLog(milliliters: amount))
                        try? context.save()
                        WidgetRefresh.reload()
                    } label: {
                        Text("+\(Int(amount)) ml")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: waterToday)
        }
    }

    private func sunCard() -> some View {
        let uv = weatherStore.today?.uvIndexMax ?? 0
        let todayLogs = sunLogs.filter { $0.date.isSameDay(as: .now) }
        let advice = VitaminDAdvisor.advise(logs: todayLogs, uvIndexToday: uv)

        return Card(title: "Nắng & vitamin D", systemImage: "sun.max.fill") {
            HStack(spacing: 12) {
                StatTile(value: "\(Int(location.distanceTodayMeters))", unit: "m", caption: "Di chuyển hôm nay", systemImage: "figure.walk.motion")
                StatTile(value: "\(Int(advice.estimatedIU))", unit: "IU", caption: "Vitamin D ước tính", systemImage: "sun.max.fill")
            }
            Button {
                showSunSheet = true
            } label: {
                Label("Ghi nhận phơi nắng", systemImage: "plus.circle")
                    .font(.subheadline)
            }

            if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
                Text("Đã tắt quyền vị trí — app không tự nhận biết bạn có ra ngoài. Bạn vẫn ghi nhận phơi nắng thủ công được.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func adviceCard(_ ctx: DayEnergyContext) -> some View {
        let items = AdviceEngine.advice(for: .init(
            ctx: ctx,
            allSessions: sessions,
            waterConsumedML: waterToday,
            sunLogsToday: sunLogs.filter { $0.date.isSameDay(as: .now) }
        ))

        return Card(title: "Lời khuyên", systemImage: "lightbulb.fill") {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.tone.color)
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)

                if index < items.count - 1 { Divider() }
            }
        }
    }

    private func row(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label).font(.caption)
            Spacer(minLength: 4)
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    var calories: Double = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title).font(.subheadline.weight(.semibold))
                Text("\(session.orderedExercises.count) bài · \(session.allSets.count) set · \(Fmt.kcal(calories))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(Array(session.musclesWorked).sorted(by: { $0.label < $1.label }).prefix(4), id: \.self) { m in
                        Text(m.label)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.brand.mutedFill(), in: Capsule())
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(session.status.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor.mutedFill(), in: Capsule())
                    .foregroundStyle(statusColor)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch session.status {
        case .planned: return .brand
        case .inProgress: return .brandWarm
        case .completed: return .brandGreen
        case .skipped: return .brandRed
        }
    }
}
