import Foundation

/// Phân loại và diễn giải thành phần cơ thể.
///
/// Ngưỡng % mỡ: ACE / American Council on Exercise.
/// Ngưỡng BMI: WHO, kèm lưu ý ngưỡng châu Á (WHO Expert Consultation 2004).
enum BodyCompositionAnalyzer {

    enum FatCategory: String {
        case essential, athlete, fitness, average, obese

        var label: String {
            switch self {
            case .essential: return "Mỡ thiết yếu"
            case .athlete: return "Vận động viên"
            case .fitness: return "Thể hình tốt"
            case .average: return "Trung bình"
            case .obese: return "Thừa mỡ"
            }
        }
    }

    static func fatCategory(bodyFatPercent bf: Double, sex: BiologicalSex) -> FatCategory {
        if sex == .male {
            switch bf {
            case ..<6: return .essential
            case 6..<14: return .athlete
            case 14..<18: return .fitness
            case 18..<25: return .average
            default: return .obese
            }
        } else {
            switch bf {
            case ..<14: return .essential
            case 14..<21: return .athlete
            case 21..<25: return .fitness
            case 25..<32: return .average
            default: return .obese
            }
        }
    }

    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    /// Phân loại BMI theo ngưỡng châu Á — phù hợp với người Việt hơn ngưỡng quốc tế.
    static func bmiCategoryAsian(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Thiếu cân"
        case 18.5..<23: return "Bình thường"
        case 23..<25: return "Thừa cân"
        case 25..<30: return "Béo phì độ I"
        default: return "Béo phì độ II"
        }
    }

    /// Ước lượng % mỡ từ vòng eo khi chưa có máy đo — công thức RFM
    /// (Woolcott & Bergman, *Scientific Reports* 2018), sai số thấp hơn BMI.
    static func relativeFatMass(heightCm: Double, waistCm: Double, sex: BiologicalSex) -> Double? {
        guard waistCm > 0, heightCm > 0 else { return nil }
        let base = 64 - 20 * (heightCm / waistCm)
        return sex == .male ? base : base + 12
    }

    /// Tỉ lệ nước trong cơ thể bình thường: nam 50-65%, nữ 45-60%.
    static func waterStatus(percent: Double, sex: BiologicalSex) -> String {
        let low: Double = sex == .male ? 50 : 45
        let high: Double = sex == .male ? 65 : 60
        if percent < low { return "Thấp hơn khoảng bình thường (\(Int(low))-\(Int(high))%) — có thể đang thiếu nước." }
        if percent > high { return "Cao hơn khoảng bình thường — có thể do giữ nước." }
        return "Nằm trong khoảng bình thường (\(Int(low))-\(Int(high))%)."
    }

    static func visceralStatus(rating: Double) -> String {
        switch rating {
        case ..<10: return "Mỡ nội tạng ở mức an toàn."
        case 10..<15: return "Mỡ nội tạng hơi cao — nên tăng vận động aerobic."
        default: return "Mỡ nội tạng cao, liên quan tới nguy cơ tim mạch và đề kháng insulin. Nên đi khám."
        }
    }

    struct Trend {
        var weightDeltaKg: Double
        var fatDeltaKg: Double?
        var leanDeltaKg: Double?
        var days: Int
        var message: String
    }

    /// So sánh lần đo mới nhất với lần đo cũ nhất trong khoảng thời gian.
    static func trend(measurements: [BodyMeasurement], days: Int = 30) -> Trend? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let sorted = measurements.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, first !== last else { return nil }

        let dWeight = last.weightKg - first.weightKg
        let dFat = (last.fatMassKg != nil && first.fatMassKg != nil) ? last.fatMassKg! - first.fatMassKg! : nil
        let dLean = (last.leanMassKg != nil && first.leanMassKg != nil) ? last.leanMassKg! - first.leanMassKg! : nil
        let span = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? days

        var msg: String
        if let df = dFat, let dl = dLean {
            if df < -0.3 && dl > -0.3 {
                msg = "Giảm \(String(format: "%.1f", -df)) kg mỡ mà vẫn giữ được cơ — đây là kết quả lý tưởng."
            } else if df < -0.3 && dl < -0.5 {
                msg = "Giảm mỡ nhưng mất \(String(format: "%.1f", -dl)) kg cơ. Tăng đạm và giữ khối lượng tập kháng lực."
            } else if df > 0.3 && dl > 0.3 {
                msg = "Tăng cả cơ lẫn mỡ. Nếu đang bulk thì bình thường; muốn sạch hơn thì giảm mức dư calo."
            } else if df > 0.5 && dl <= 0 {
                msg = "Chủ yếu tăng mỡ. Xem lại lượng calo nạp và khối lượng tập."
            } else {
                msg = "Thành phần cơ thể thay đổi ít trong \(span) ngày."
            }
        } else {
            msg = dWeight < 0
                ? "Giảm \(String(format: "%.1f", -dWeight)) kg trong \(span) ngày. Nhập thêm % mỡ để biết đang giảm mỡ hay giảm cơ."
                : "Thay đổi \(String(format: "%+.1f", dWeight)) kg trong \(span) ngày."
        }

        // Tốc độ thay đổi an toàn: 0.5-1% cân nặng mỗi tuần.
        if span > 6 {
            let weeklyPct = abs(dWeight) / last.weightKg / (Double(span) / 7) * 100
            if weeklyPct > 1.2 {
                msg += " Tốc độ \(String(format: "%.1f", weeklyPct))%/tuần là nhanh — mức bền vững là 0.5-1%/tuần."
            }
        }

        return Trend(weightDeltaKg: dWeight, fatDeltaKg: dFat, leanDeltaKg: dLean, days: span, message: msg)
    }
}
