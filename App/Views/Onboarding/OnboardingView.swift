import SwiftUI
import SwiftData

/// Hỏi thông tin cá nhân hoá lần đầu mở app — mỗi màn một câu hỏi.
///
/// Mọi thứ hỏi ở đây đều sửa lại được trong Cài đặt, nên các bước không bắt buộc
/// đều có nút bỏ qua; app vẫn chạy được với giá trị mặc định.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    var onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, name, sex, birthDate, height, weight, bodyFat, activity, goals, conditions, done

        var isSkippable: Bool {
            switch self {
            case .name, .bodyFat, .conditions: return true
            default: return false
            }
        }
    }

    @State private var step: Step = .welcome

    // Dữ liệu thu thập
    @State private var name = ""
    @State private var sex: BiologicalSex = .male
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 65
    @State private var hasBodyFat = false
    @State private var bodyFat: Double = 20
    @State private var activity: ActivityLevel = .moderate
    @State private var goals: Set<GoalType> = [.health]
    @State private var conditions: Set<HealthConditionKind> = []

    private var progress: Double {
        Double(step.rawValue) / Double(Step.allCases.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }

            footer
        }
        .background(Color.appBackground.ignoresSafeArea())
        .preferredColorScheme(ThemeState.shared.forcedColorScheme)
    }

    // MARK: - Khung

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if step != .welcome && step != .done {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { back() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                }
                Spacer()
                if step.isSkippable {
                    Button("Bỏ qua") {
                        withAnimation(.easeInOut(duration: 0.2)) { advance() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(height: 22)

            if step != .welcome {
                ProgressView(value: progress)
                    .tint(Color.brand)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                if step == .done {
                    commit()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) { advance() }
                }
            } label: {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(step == .welcome ? IconPalette.training : Color.brand,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(step == .welcome ? Color.black : Color.onBrand)
            }
            .disabled(step == .goals && goals.isEmpty)
            .opacity(step == .goals && goals.isEmpty ? 0.5 : 1)
        }
        .padding(20)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: return "Bắt đầu"
        case .done: return "Vào app"
        default: return "Tiếp tục"
        }
    }

    // MARK: - Nội dung từng bước

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            question("Chào mừng đến Mufit", "Vài câu hỏi ngắn để app tính đúng nhu cầu calo, nước và gợi ý bài tập cho riêng bạn. Đổi lại sau trong Cài đặt lúc nào cũng được.")
            VStack(alignment: .leading, spacing: 14) {
                bulletRow("figure.strengthtraining.traditional", "Lịch tập theo tuần", "Tự setup bài, set, reps, drop set và superset")
                bulletRow("flame.fill", "Calo vào và ra", "Tính theo khối nạc, cường độ tập và cả thời tiết")
                bulletRow("heart.text.square.fill", "Gợi ý theo bệnh nền", "Tổng hợp từ khuyến nghị của các hội chuyên ngành")
            }

        case .name:
            question("Gọi bạn là gì?", "Chỉ để app xưng hô cho thân thiện. Không bắt buộc.")
            TextField("Tên của bạn", text: $name)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .sex:
            question("Giới tính sinh học", "Công thức chuyển hoá cơ bản và nhu cầu nước khác nhau giữa nam và nữ.")
            VStack(spacing: 10) {
                ForEach(BiologicalSex.allCases) { s in
                    choiceRow(title: s.label, subtitle: nil,
                              icon: s == .male ? "figure.stand" : "figure.stand.dress",
                              isOn: sex == s) { sex = s }
                }
            }

        case .birthDate:
            question("Bạn sinh năm nào?", "Tuổi ảnh hưởng trực tiếp tới mức chuyển hoá cơ bản.")
            DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

        case .height:
            question("Chiều cao của bạn?", "Dùng để tính BMI và chuyển hoá cơ bản.")
            valueStepper(value: $heightCm, range: 120...220, step: 1, unit: "cm", format: "%.0f")

        case .weight:
            question("Cân nặng hiện tại?", "App lưu đây thành lần đo đầu tiên, sau này cân lại thì thêm số đo mới.")
            valueStepper(value: $weightKg, range: 30...200, step: 0.5, unit: "kg", format: "%.1f")

        case .bodyFat:
            question("Bạn có biết % mỡ cơ thể?", "Có số này thì app dùng công thức Katch-McArdle theo khối nạc — chính xác hơn hẳn. Không có cũng không sao.")
            Toggle("Tôi có số đo % mỡ", isOn: $hasBodyFat)
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if hasBodyFat {
                valueStepper(value: $bodyFat, range: 3...60, step: 0.5, unit: "%", format: "%.1f")
                Text(BodyCompositionAnalyzer.fatCategory(bodyFatPercent: bodyFat, sex: sex).label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .activity:
            question("Mức vận động hằng ngày?", "Tính cả công việc và sinh hoạt, chưa tính buổi tập bạn ghi trong app.")
            VStack(spacing: 10) {
                ForEach(ActivityLevel.allCases) { level in
                    choiceRow(title: level.label,
                              subtitle: "Hệ số ×\(String(format: "%.3f", level.multiplier))",
                              icon: "figure.walk",
                              isOn: activity == level) { activity = level }
                }
            }

        case .goals:
            question("Mục tiêu của bạn?", "Chọn được nhiều mục tiêu cùng lúc. Chọn cả giảm mỡ lẫn tăng cơ nghĩa là tái cấu trúc cơ thể.")
            VStack(spacing: 10) {
                ForEach(GoalType.allCases) { goal in
                    choiceRow(title: goal.label, subtitle: goal.detail,
                              icon: goal.systemImage,
                              isOn: goals.contains(goal)) {
                        if goals.contains(goal) { goals.remove(goal) } else { goals.insert(goal) }
                    }
                }
            }

        case .conditions:
            question("Bạn có bệnh nền nào không?", "App sẽ điều chỉnh gợi ý bài tập và cảnh báo an toàn. Bỏ qua nếu không có.")
            VStack(spacing: 8) {
                ForEach(HealthConditionKind.allCases.filter { $0 != .none }) { c in
                    choiceRow(title: c.label, subtitle: nil, icon: "cross.case.fill",
                              isOn: conditions.contains(c)) {
                        if conditions.contains(c) { conditions.remove(c) } else { conditions.insert(c) }
                    }
                }
            }
            Text(ConditionAdvisor.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)

        case .done:
            question(name.isEmpty ? "Xong rồi!" : "Xong rồi, \(name)!", "Đây là mức app tính cho bạn dựa trên thông tin vừa nhập.")
            VStack(spacing: 12) {
                summaryRow("flame.fill", "Chuyển hoá cơ bản", "\(Int(previewBMR)) kcal/ngày")
                summaryRow("figure.walk", "TDEE", "\(Int(previewTDEE)) kcal/ngày")
                summaryRow("target", "Mục tiêu nạp", "\(Int(previewTarget)) kcal/ngày")
                summaryRow("drop.fill", "Nước", "\(Int(previewWater)) ml/ngày")
            }
            Text("Con số sẽ tự điều chỉnh theo buổi tập, thời tiết và các lần cân sau.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Thành phần dùng lại

    private func question(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.largeTitle, design: .default).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brand)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func choiceRow(title: String, subtitle: String?, icon: String,
                           isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(isOn ? Color.brand : Color.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body.weight(.medium))
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.brand : Color.secondary.opacity(0.5))
            }
            .padding(14)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func valueStepper(value: Binding<Double>, range: ClosedRange<Double>,
                              step stepValue: Double, unit: String, format: String) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: format, value.wrappedValue))
                    .font(.metric(52))
                Text(unit)
                    .font(.unitLabel)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Slider(value: value, in: range, step: stepValue)
                .tint(Color.brand)

            HStack {
                Text(String(format: format, range.lowerBound) + " " + unit)
                Spacer()
                Text(String(format: format, range.upperBound) + " " + unit)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.brand).frame(width: 24)
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Điều hướng và lưu

    private func advance() {
        let all = Step.allCases
        guard let idx = all.firstIndex(of: step), idx + 1 < all.count else { return }
        step = all[idx + 1]
    }

    private func back() {
        let all = Step.allCases
        guard let idx = all.firstIndex(of: step), idx > 0 else { return }
        step = all[idx - 1]
    }

    private var draftProfile: UserProfile {
        UserProfile(name: name, sex: sex, birthDate: birthDate, heightCm: heightCm,
                    activityLevel: activity, goals: Array(goals), conditions: Array(conditions))
    }

    private var draftMeasurement: BodyMeasurement {
        BodyMeasurement(weightKg: weightKg, bodyFatPercent: hasBodyFat ? bodyFat : nil)
    }

    private var previewBMR: Double {
        EnergyCalculator.restingEnergy(profile: draftProfile, measurement: draftMeasurement)
    }

    private var previewTDEE: Double {
        EnergyCalculator.totalDailyEnergy(profile: draftProfile, measurement: draftMeasurement, weather: nil)
    }

    private var previewTarget: Double {
        EnergyCalculator.dailyCalorieTarget(profile: draftProfile, measurement: draftMeasurement,
                                            weather: nil, workoutCalories: 0)
    }

    private var previewWater: Double {
        HydrationAdvisor.recommend(weightKg: weightKg, sex: sex, trainingMinutes: 0, weather: nil).totalML
    }

    private func commit() {
        // Hồ sơ đã được tạo sẵn lúc seed, nên cập nhật thay vì tạo mới.
        let profile = profiles.first ?? {
            let p = UserProfile()
            context.insert(p)
            return p
        }()

        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.sex = sex
        profile.birthDate = birthDate
        profile.heightCm = heightCm
        profile.activityLevel = activity
        profile.goals = goals.isEmpty ? [.health] : Array(goals)
        profile.conditions = Array(conditions)

        context.insert(draftMeasurement)
        try? context.save()

        onFinish()
    }
}
