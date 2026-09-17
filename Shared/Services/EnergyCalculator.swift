import Foundation

/// Toàn bộ phép tính năng lượng của app.
///
/// Nguồn công thức:
/// - BMR Mifflin-St Jeor: Mifflin MD et al., *Am J Clin Nutr* 1990;51(2):241-7.
/// - BMR Katch-McArdle (khi biết khối nạc): McArdle WD, *Exercise Physiology*, 8th ed.
/// - MET: Ainsworth BE et al., *Compendium of Physical Activities*, Med Sci Sports Exerc 2011.
/// - Hiệu chỉnh nhiệt: Consolazio CF, *Metabolic Methods* — chi phí trao đổi chất tăng
///   ở cả môi trường nóng (điều nhiệt bay hơi) lẫn lạnh (sinh nhiệt run cơ).
enum EnergyCalculator {

    // MARK: - Chuyển hoá cơ bản

    /// BMR theo Mifflin-St Jeor. Dùng khi chưa có số liệu mỡ cơ thể.
    static func bmrMifflin(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    /// BMR theo Katch-McArdle. Chính xác hơn khi đã biết % mỡ.
    static func bmrKatchMcArdle(leanMassKg: Double) -> Double {
        370 + 21.6 * leanMassKg
    }

    /// Chọn công thức tốt nhất với dữ liệu đang có.
    static func restingEnergy(profile: UserProfile, measurement: BodyMeasurement?) -> Double {
        guard let m = measurement else {
            return bmrMifflin(weightKg: 70, heightCm: profile.heightCm, age: profile.age, sex: profile.sex)
        }
        if let lean = m.leanMassKg, lean > 0 {
            return bmrKatchMcArdle(leanMassKg: lean)
        }
        return bmrMifflin(weightKg: m.weightKg, heightCm: profile.heightCm, age: profile.age, sex: profile.sex)
    }

    /// TDEE = BMR × hệ số hoạt động, đã hiệu chỉnh theo nhiệt độ môi trường.
    static func totalDailyEnergy(
        profile: UserProfile,
        measurement: BodyMeasurement?,
        weather: WeatherSnapshot?
    ) -> Double {
        let bmr = restingEnergy(profile: profile, measurement: measurement)
        let base = bmr * profile.activityLevel.multiplier
        return base * thermalMultiplier(for: weather)
    }

    // MARK: - Hiệu chỉnh theo mùa / nhiệt độ

    /// Hệ số nhân chi phí năng lượng theo nhiệt độ môi trường.
    ///
    /// Đường cong hình chữ U: thấp nhất ở vùng trung tính nhiệt (20-24°C),
    /// tăng lên ở cả hai đầu nóng và lạnh. Biên độ giữ ở mức thận trọng (tối đa +11%)
    /// vì y văn cho thấy hiệu ứng thật nhưng khiêm tốn ở người mặc đủ ấm / có thích nghi nhiệt.
    static func thermalMultiplier(for weather: WeatherSnapshot?) -> Double {
        guard let w = weather else { return 1.0 }
        let t = w.meanTempC
        let humidityBoost = w.humidityPercent > 70 && t > 28 ? 0.02 : 0

        switch t {
        case 34...:      return 1.09 + humidityBoost   // stress nhiệt nặng
        case 30..<34:    return 1.06 + humidityBoost
        case 26..<30:    return 1.03 + humidityBoost
        case 20..<26:    return 1.00                   // vùng trung tính nhiệt
        case 14..<20:    return 1.02
        case 8..<14:     return 1.05
        case 0..<8:      return 1.08
        default:         return 1.11                   // dưới 0°C
        }
    }

    static func seasonNote(for weather: WeatherSnapshot?) -> String {
        guard let w = weather else { return "Chưa có dữ liệu thời tiết." }
        let pct = Int(((thermalMultiplier(for: w) - 1) * 100).rounded())
        switch w.season {
        case .hot:
            return "Trời nóng \(Int(w.meanTempC))°C — cơ thể tốn thêm ~\(pct)% năng lượng để điều nhiệt, và mất nước nhanh hơn nhiều."
        case .warm:
            return "Trời ấm \(Int(w.meanTempC))°C — tiêu hao tăng nhẹ ~\(pct)%, chú ý bù nước khi tập."
        case .temperate:
            return "Nhiệt độ \(Int(w.meanTempC))°C nằm trong vùng trung tính nhiệt, tiêu hao không bị cộng thêm."
        case .cool:
            return "Trời mát \(Int(w.meanTempC))°C — cơ thể tốn thêm ~\(pct)% để giữ ấm. Khởi động kỹ hơn."
        case .cold:
            return "Trời lạnh \(Int(w.meanTempC))°C — sinh nhiệt tăng ~\(pct)%. Khởi động dài hơn để tránh chấn thương."
        }
    }

    // MARK: - Calo buổi tập

    /// Calo đốt của một set: MET × 3.5 × kg / 200 (kcal/phút) × thời lượng × hệ số kiểu set.
    ///
    /// Thời lượng set ước lượng từ số reps (≈3 giây/rep) cộng thời gian nghỉ sau đó,
    /// vì nghỉ giữa set vẫn tiêu hao trên mức nghỉ ngơi (EPOC ngắn hạn).
    static func caloriesForSet(_ set: SetLog, bodyWeightKg: Double, met: Double, restSeconds: Int) -> Double {
        let reps = Double(set.actualReps ?? set.targetReps)
        let dropReps = set.dropReps.reduce(0, +)
        let workSeconds = (reps + Double(dropReps)) * 3.0
        let restFactor = 0.35  // nghỉ tiêu hao ~35% so với lúc đang nâng
        let effectiveMinutes = (workSeconds + Double(restSeconds) * restFactor) / 60

        let kcalPerMinute = met * 3.5 * bodyWeightKg / 200
        return kcalPerMinute * effectiveMinutes * set.setType.intensityFactor
    }

    /// Tổng calo của cả buổi tập, có nhân hệ số nhiệt độ.
    static func caloriesForSession(
        _ session: WorkoutSession,
        bodyWeightKg: Double,
        weather: WeatherSnapshot?
    ) -> Double {
        var total: Double = 0
        for se in session.orderedExercises {
            let met = se.exercise?.met ?? 5.0
            // Superset không nghỉ giữa các bài nên tính rest bằng 0 cho bài không phải cuối nhóm.
            let rest = se.supersetGroup == nil ? se.restSeconds : 0
            for set in se.orderedSets where set.isCompleted || session.status == .planned {
                total += caloriesForSet(set, bodyWeightKg: bodyWeightKg, met: met, restSeconds: rest)
            }
        }
        return total * thermalMultiplier(for: weather)
    }

    // MARK: - Mục tiêu calo

    /// Mục tiêu nạp trong ngày = TDEE + calo tập + offset theo mục tiêu.
    static func dailyCalorieTarget(
        profile: UserProfile,
        measurement: BodyMeasurement?,
        weather: WeatherSnapshot?,
        workoutCalories: Double
    ) -> Double {
        let tdee = totalDailyEnergy(profile: profile, measurement: measurement, weather: weather)
        let gross = tdee + workoutCalories
        return gross * (1 + profile.calorieOffsetRatio)
    }

    /// Phân bổ macro. Protein tính theo khối nạc nếu có (2.0 g/kg lean — ngưỡng trên
    /// của khuyến nghị ISSN cho người tập kháng lực trong giai đoạn thâm hụt).
    static func macroTargets(
        calories: Double,
        profile: UserProfile,
        measurement: BodyMeasurement?
    ) -> MacroTotals {
        let weight = measurement?.weightKg ?? 70
        let lean = measurement?.leanMassKg ?? weight * 0.8

        let proteinG: Double
        if profile.isRecomposition {
            // Vừa giảm mỡ vừa tăng cơ là tình huống đòi hỏi đạm cao nhất.
            proteinG = lean * 2.6
        } else {
            switch profile.primaryCompositionGoal {
            case .cut: proteinG = lean * 2.4
            case .bulk: proteinG = lean * 1.8
            default: proteinG = lean * 2.0
            }
        }

        // Mỡ tối thiểu 0.8 g/kg cân nặng để bảo vệ nội tiết.
        let fatG = max(weight * 0.8, calories * 0.25 / 9)
        let remaining = max(0, calories - proteinG * 4 - fatG * 9)
        let carbG = remaining / 4

        return MacroTotals(
            calories: calories,
            protein: proteinG,
            carbs: carbG,
            fat: fatG,
            fiber: calories / 1000 * 14,   // 14 g/1000 kcal — khuyến nghị Institute of Medicine
            sodiumMg: 2300,
            sugar: calories * 0.10 / 4     // WHO: đường tự do < 10% năng lượng
        )
    }
}
