import Foundation
import SwiftUI

/// Gom mọi lời khuyên rải rác trong các thẻ về một chỗ.
///
/// Mỗi lời khuyên đều bắt nguồn từ số liệu thật của người dùng hôm nay — cân bằng
/// calo, thời tiết đang ghi nhận, lượng nước đã uống, phơi nắng, phân bổ nhóm cơ
/// và bệnh nền đã khai báo. Không có câu chung chung nào được sinh ra nếu thiếu dữ liệu.
enum AdviceEngine {

    enum Tone {
        case alert, warning, info

        var color: Color {
            switch self {
            case .alert: return AlertPalette.over
            case .warning: return IconPalette.energy
            case .info: return IconPalette.insight
            }
        }
    }

    struct Item: Identifiable {
        let id = UUID()
        var icon: String
        var title: String
        var detail: String
        var tone: Tone
    }

    struct Input {
        var ctx: DayEnergyContext
        var allSessions: [WorkoutSession]
        var waterConsumedML: Double
        var sunLogsToday: [SunExposureLog]
    }

    static func advice(for input: Input) -> [Item] {
        var items: [Item] = []
        let ctx = input.ctx

        items.append(contentsOf: energyAdvice(ctx))
        if let seasonItem = seasonAdvice(ctx) { items.append(seasonItem) }
        items.append(hydrationAdvice(input))
        items.append(vitaminDAdvice(input))
        items.append(contentsOf: nutritionAdvice(ctx))
        items.append(contentsOf: trainingAdvice(input))
        if let conditionItem = conditionAdvice(ctx) { items.append(conditionItem) }

        // Việc cần xử lý gấp đứng trước.
        let rank: (Tone) -> Int = { t in
            switch t {
            case .alert: return 0
            case .warning: return 1
            case .info: return 2
            }
        }
        // Giới hạn 6 mục: quá nhiều lời khuyên một lúc thì không ai đọc hết.
        return Array(items.sorted { rank($0.tone) < rank($1.tone) }.prefix(6))
    }

    // MARK: - Năng lượng

    private static func energyAdvice(_ ctx: DayEnergyContext) -> [Item] {
        guard ctx.consumed.calories > 0 else {
            return [Item(
                icon: "fork.knife",
                title: "Chưa ghi bữa nào hôm nay",
                detail: "Mục tiêu của bạn là \(Fmt.kcal(ctx.calorieTarget)). Ghi bữa ăn để app theo được cân bằng năng lượng.",
                tone: .info
            )]
        }

        let balance = ctx.energyBalance
        let profile = ctx.profile

        if profile.isRecomposition {
            if abs(balance) < 250 {
                return [Item(icon: "equal.circle.fill", title: "Đang đúng vùng tái cấu trúc",
                             detail: "Lệch \(Int(abs(balance))) kcal so với mức duy trì — vừa đủ để giảm mỡ mà vẫn tăng cơ.",
                             tone: .info)]
            }
            return [Item(
                icon: balance < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                title: balance < 0 ? "Hụt hơi sâu cho mục tiêu recomp" : "Dư hơi nhiều cho mục tiêu recomp",
                detail: balance < 0
                    ? "Đang hụt \(Int(-balance)) kcal. Recomp cần ăn quanh mức duy trì; hụt sâu sẽ mất đà tăng cơ."
                    : "Đang dư \(Int(balance)) kcal. Phần dư vượt quá nhu cầu tăng cơ sẽ tích thành mỡ.",
                tone: .warning)]
        }

        switch profile.primaryCompositionGoal {
        case .cut:
            if balance > 0 {
                return [Item(icon: "exclamationmark.triangle.fill", title: "Ăn dư dù mục tiêu là giảm mỡ",
                             detail: "Đang dư \(Int(balance)) kcal so với mức tiêu hao. Cần cắt khoảng \(Int(balance + 400)) kcal để quay về mức thâm hụt hợp lý.",
                             tone: .alert)]
            }
            if -balance > 1000 {
                return [Item(icon: "exclamationmark.triangle.fill", title: "Thâm hụt quá sâu",
                             detail: "Đang hụt \(Int(-balance)) kcal. Hụt trên 1000 kcal kéo dài làm mất cơ và giảm nội tiết. Nên giữ trong khoảng 300-700 kcal.",
                             tone: .warning)]
            }
            return [Item(icon: "checkmark.seal.fill", title: "Mức thâm hụt hợp lý",
                         detail: "Đang hụt \(Int(-balance)) kcal — tốc độ giảm mỡ bền vững, ít nguy cơ mất cơ.",
                         tone: .info)]

        case .bulk:
            if balance < 0 {
                return [Item(icon: "exclamationmark.triangle.fill", title: "Thiếu calo cho mục tiêu tăng cơ",
                             detail: "Đang hụt \(Int(-balance)) kcal. Cơ không tăng được khi thiếu năng lượng — cần nạp thêm khoảng \(Int(-balance + 300)) kcal.",
                             tone: .alert)]
            }
            if balance > 700 {
                return [Item(icon: "arrow.up.circle.fill", title: "Dư hơi nhiều",
                             detail: "Đang dư \(Int(balance)) kcal. Trên 500 kcal thặng dư thì phần vượt chủ yếu thành mỡ chứ không thành cơ.",
                             tone: .warning)]
            }
            return [Item(icon: "checkmark.seal.fill", title: "Mức dư hợp lý để tăng cơ",
                         detail: "Đang dư \(Int(balance)) kcal — vừa đủ để xây cơ mà không tích mỡ nhanh.",
                         tone: .info)]

        default:
            if abs(balance) < 200 {
                return [Item(icon: "checkmark.seal.fill", title: "Cân bằng tốt",
                             detail: "Lệch \(Int(abs(balance))) kcal so với mức duy trì — đúng mục tiêu giữ nguyên.",
                             tone: .info)]
            }
            return [Item(icon: "exclamationmark.triangle.fill", title: "Lệch khá nhiều so với mức duy trì",
                         detail: balance < 0 ? "Đang hụt \(Int(-balance)) kcal." : "Đang dư \(Int(balance)) kcal.",
                         tone: .warning)]
        }
    }

    // MARK: - Thời tiết

    private static func seasonAdvice(_ ctx: DayEnergyContext) -> Item? {
        guard let w = ctx.weather else { return nil }
        let percent = Int(((EnergyCalculator.thermalMultiplier(for: w) - 1) * 100).rounded())

        switch w.season {
        case .hot:
            return Item(icon: "thermometer.sun.fill", title: "Trời nóng \(Int(w.meanTempC))°C",
                        detail: "Điều nhiệt tốn thêm ~\(percent)% năng lượng và bạn mất nước nhanh hơn nhiều. Tập sớm hoặc muộn trong ngày, uống từng ngụm đều đặn.",
                        tone: .warning)
        case .warm:
            return Item(icon: "sun.max.fill", title: "Trời ấm \(Int(w.meanTempC))°C",
                        detail: "Tiêu hao tăng nhẹ ~\(percent)%. Chú ý bù nước trong buổi tập.",
                        tone: .info)
        case .temperate:
            return Item(icon: "cloud.sun.fill", title: "Nhiệt độ lý tưởng \(Int(w.meanTempC))°C",
                        detail: "Nằm trong vùng trung tính nhiệt — cơ thể không tốn thêm năng lượng để điều nhiệt. Điều kiện tốt nhất để tập nặng.",
                        tone: .info)
        case .cool, .cold:
            return Item(icon: "thermometer.snowflake", title: "Trời \(w.season.label.lowercased()) \(Int(w.meanTempC))°C",
                        detail: "Cơ thể tốn thêm ~\(percent)% để giữ ấm. Khởi động dài hơn bình thường vì cơ nguội dễ chấn thương.",
                        tone: .info)
        }
    }

    // MARK: - Nước

    private static func hydrationAdvice(_ input: Input) -> Item {
        let ctx = input.ctx
        let rec = HydrationAdvisor.recommend(
            weightKg: ctx.bodyWeight, sex: ctx.profile.sex,
            trainingMinutes: ctx.trainingMinutes, weather: ctx.weather
        )
        let remaining = rec.totalML - input.waterConsumedML

        if remaining <= 0 {
            return Item(icon: "drop.fill", title: "Đã uống đủ nước",
                        detail: "\(Fmt.ml(input.waterConsumedML)) hôm nay, đạt mục tiêu \(Fmt.ml(rec.totalML)).",
                        tone: .info)
        }

        var reasons: [String] = []
        if rec.trainingML > 0 {
            reasons.append("\(Int(rec.trainingML)) ml cho \(Int(ctx.trainingMinutes)) phút tập")
        }
        if rec.climateML > 0 {
            reasons.append("\(Int(rec.climateML)) ml do thời tiết")
        }
        let because = reasons.isEmpty ? "" : " Trong đó có " + reasons.joined(separator: " và ") + "."

        return Item(
            icon: "drop.fill",
            title: "Còn thiếu \(Fmt.ml(remaining)) nước",
            detail: "Mục tiêu hôm nay là \(Fmt.ml(rec.totalML))." + because + " Khoảng 20-30% nhu cầu đã đến từ thức ăn.",
            tone: remaining > rec.totalML * 0.6 ? .warning : .info
        )
    }

    // MARK: - Vitamin D

    private static func vitaminDAdvice(_ input: Input) -> Item {
        let uv = input.ctx.weather?.uvIndexMax ?? 0
        let advice = VitaminDAdvisor.advise(logs: input.sunLogsToday, uvIndexToday: uv)
        return Item(
            icon: "sun.max.fill",
            title: advice.estimatedIU >= 800 ? "Đủ vitamin D hôm nay" : "Vitamin D còn thiếu",
            detail: advice.message,
            tone: advice.estimatedIU >= 800 ? .info : .warning
        )
    }

    // MARK: - Dinh dưỡng

    private static func nutritionAdvice(_ ctx: DayEnergyContext) -> [Item] {
        guard ctx.consumed.calories > 0 else { return [] }
        let gaps = NutritionGapAdvisor.gaps(consumed: ctx.consumed, target: ctx.macroTarget)

        var items: [Item] = []

        for gap in gaps where gap.isExcess && gap.nutrient != "Calo" {
            items.append(Item(
                icon: "exclamationmark.triangle.fill",
                title: "\(gap.nutrient) vượt ngưỡng",
                detail: "Đã nạp \(Int(gap.consumed)) \(gap.unit), vượt \(Int(gap.consumed - gap.target)) \(gap.unit) so với mục tiêu. " + gap.suggestion,
                tone: .alert
            ))
        }

        // Chỉ nêu khoảng thiếu lớn nhất để lời khuyên không loãng.
        if let worst = gaps.filter({ $0.isDeficit && $0.nutrient != "Natri" })
            .min(by: { $0.ratio < $1.ratio }) {
            items.append(Item(
                icon: "arrow.down.circle.fill",
                title: "Thiếu \(worst.nutrient.lowercased()) nhiều nhất",
                detail: worst.suggestion,
                tone: .warning
            ))
        }

        return items
    }

    // MARK: - Tập luyện

    private static func trainingAdvice(_ input: Input) -> [Item] {
        var items: [Item] = []

        let alerts = MuscleBalanceAnalyzer.alerts(sessions: input.allSessions, days: 14)
        if let top = alerts.first {
            let tone: Tone
            switch top.severity {
            case .critical: tone = .alert
            case .warning: tone = .warning
            case .info: tone = .info
            }
            items.append(Item(icon: "figure.strengthtraining.traditional",
                              title: top.title, detail: top.detail, tone: tone))
        }

        let rate = MuscleBalanceAnalyzer.averageCompletionRate(sessions: input.allSessions, days: 14)
        if rate >= 0.98 {
            items.append(Item(icon: "arrow.up.circle.fill", title: "Đã đến lúc tăng tải",
                              detail: "Hai tuần qua bạn hoàn thành \(Int(rate * 100))% số reps đã set up. Tăng 2.5-5% mức tạ hoặc thêm 1 rep mỗi set cho buổi tới.",
                              tone: .info))
        } else if rate > 0 && rate < 0.75 {
            items.append(Item(icon: "arrow.down.circle.fill", title: "Hiệu suất tập đang thấp",
                              detail: "Hai tuần qua chỉ đạt \(Int(rate * 100))% số reps dự kiến. Thường là do tạ quá nặng, thiếu ngủ hoặc thâm hụt calo quá sâu. Thử giảm 5-10% mức tạ.",
                              tone: .warning))
        }

        return items
    }

    // MARK: - Bệnh nền

    private static func conditionAdvice(_ ctx: DayEnergyContext) -> Item? {
        let guidance = ConditionAdvisor.allGuidance(for: ctx.profile.conditions)
        guard let first = guidance.first, let tip = first.recommended.first else { return nil }
        return Item(icon: "cross.case.fill",
                    title: "Nhắc theo \(first.condition.label.lowercased())",
                    detail: tip,
                    tone: .info)
    }
}
