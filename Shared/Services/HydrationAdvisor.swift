import Foundation

/// Ước lượng nhu cầu nước.
///
/// Nền: EFSA 2010 khuyến nghị tổng lượng nước 2.5 L/ngày (nam), 2.0 L (nữ) ở khí hậu ôn hoà,
/// trong đó ~20-30% đến từ thức ăn. ACSM khuyến nghị bù 0.4-0.8 L cho mỗi giờ vận động,
/// tăng thêm khi trời nóng ẩm.
enum HydrationAdvisor {

    struct Recommendation {
        var baselineML: Double
        var trainingML: Double
        var climateML: Double
        var totalML: Double
        var notes: [String]
    }

    static func recommend(
        weightKg: Double,
        sex: BiologicalSex,
        trainingMinutes: Double,
        weather: WeatherSnapshot?
    ) -> Recommendation {
        var notes: [String] = []

        // 33 ml/kg cho nam, 31 ml/kg cho nữ — quy đổi từ mốc EFSA về mức cân nặng.
        let perKg: Double = sex == .male ? 33 : 31
        let baseline = weightKg * perKg

        // ACSM: ~600 ml mỗi giờ vận động ở cường độ vừa.
        let training = trainingMinutes / 60 * 600
        if trainingMinutes > 0 {
            notes.append("Thêm \(Int(training)) ml cho \(Int(trainingMinutes)) phút tập.")
        }

        var climate: Double = 0
        if let w = weather {
            switch w.season {
            case .hot:
                climate = 700
                notes.append("Trời nóng \(Int(w.meanTempC))°C: cộng thêm 700 ml.")
            case .warm:
                climate = 350
                notes.append("Trời ấm: cộng thêm 350 ml.")
            case .cold:
                climate = 150
                notes.append("Trời lạnh làm giảm cảm giác khát nhưng vẫn mất nước qua hô hấp: cộng 150 ml.")
            default:
                break
            }
            if w.humidityPercent > 75 && w.meanTempC > 27 {
                climate += 250
                notes.append("Độ ẩm \(Int(w.humidityPercent))% cản trở bay hơi mồ hôi: cộng thêm 250 ml.")
            }
        }

        let total = baseline + training + climate
        notes.append("Khoảng 20-30% nhu cầu này đã đến từ thức ăn, phần còn lại cần uống.")

        return Recommendation(
            baselineML: baseline,
            trainingML: training,
            climateML: climate,
            totalML: total,
            notes: notes
        )
    }
}

/// Gợi ý vitamin D dựa trên phơi nắng thực tế.
///
/// Nền: Holick MF, *N Engl J Med* 2007 — tổng hợp vitamin D ở da phụ thuộc UV-B,
/// diện tích da hở và thời lượng. Endocrine Society khuyến nghị 600-800 IU/ngày
/// cho người trưởng thành khi không đủ nắng.
enum VitaminDAdvisor {

    struct Advice {
        var estimatedIU: Double
        var recommendedSupplementIU: Double
        var suggestedMinutesToday: Double
        var message: String
    }

    /// Thời lượng phơi nắng đủ cho ~1000 IU với 25% da hở, theo chỉ số UV.
    static func minutesForTarget(uvIndex: Double, skinExposurePercent: Double) -> Double {
        guard uvIndex > 0 else { return .infinity }
        let areaFactor = max(0.1, skinExposurePercent / 25)
        // Ở UV 6, ~15 phút với 25% da hở cho khoảng 1000 IU.
        return (15 * 6 / uvIndex) / areaFactor
    }

    static func estimateIU(minutes: Double, uvIndex: Double, skinExposurePercent: Double) -> Double {
        let needed = minutesForTarget(uvIndex: uvIndex, skinExposurePercent: skinExposurePercent)
        guard needed.isFinite, needed > 0 else { return 0 }
        // Tổng hợp bão hoà: vượt quá ~3× ngưỡng thì không tăng thêm.
        let ratio = min(minutes / needed, 3.0)
        return ratio * 1000
    }

    static func advise(logs: [SunExposureLog], uvIndexToday: Double) -> Advice {
        let todayIU = logs.reduce(0.0) {
            $0 + estimateIU(minutes: $1.minutes, uvIndex: $1.uvIndex, skinExposurePercent: $1.skinExposurePercent)
        }

        let dailyTarget: Double = 800
        let deficit = max(0, dailyTarget - todayIU)
        let minutesNeeded = minutesForTarget(uvIndex: uvIndexToday, skinExposurePercent: 25)

        let message: String
        if todayIU >= dailyTarget {
            message = "Bạn đã phơi nắng đủ hôm nay (~\(Int(todayIU)) IU). Không cần bổ sung thêm vitamin D."
        } else if uvIndexToday < 3 {
            message = "Chỉ số UV hôm nay chỉ \(String(format: "%.1f", uvIndexToday)) — quá thấp để da tổng hợp vitamin D hiệu quả. Cân nhắc bổ sung ~\(Int(deficit)) IU qua viên uống hoặc thực phẩm (cá béo, lòng đỏ trứng, nấm phơi nắng)."
        } else if minutesNeeded.isFinite {
            message = "Còn thiếu ~\(Int(deficit)) IU. Phơi nắng thêm khoảng \(Int(minutesNeeded)) phút (tay + chân hở, tránh khung 11h-15h nếu UV > 8) là đủ."
        } else {
            message = "Chưa đủ dữ liệu UV để ước lượng."
        }

        return Advice(
            estimatedIU: todayIU,
            recommendedSupplementIU: deficit,
            suggestedMinutesToday: minutesNeeded.isFinite ? minutesNeeded : 0,
            message: message
        )
    }
}
