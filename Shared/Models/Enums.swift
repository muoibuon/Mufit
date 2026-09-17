import Foundation

// MARK: - Hồ sơ cơ thể

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String { self == .male ? "Nam" : "Nữ" }
}

/// Hệ số hoạt động dùng cho công thức TDEE (Mifflin-St Jeor).
enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var label: String {
        switch self {
        case .sedentary: return "Ít vận động (ngồi nhiều)"
        case .light: return "Nhẹ (1-3 buổi/tuần)"
        case .moderate: return "Vừa (3-5 buổi/tuần)"
        case .active: return "Nhiều (6-7 buổi/tuần)"
        case .veryActive: return "Rất nhiều (2 buổi/ngày, lao động nặng)"
        }
    }
}

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case cut, maintain, bulk, strength, endurance, health

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cut: return "Giảm mỡ"
        case .maintain: return "Giữ nguyên"
        case .bulk: return "Tăng cơ"
        case .strength: return "Tăng sức mạnh"
        case .endurance: return "Tăng sức bền"
        case .health: return "Cải thiện sức khoẻ"
        }
    }

    var detail: String {
        switch self {
        case .cut: return "Ăn thâm hụt calo, giữ đạm cao để không mất cơ"
        case .maintain: return "Giữ cân nặng và thể trạng hiện tại"
        case .bulk: return "Ăn dư calo có kiểm soát để tăng khối cơ"
        case .strength: return "Tập nặng, ít reps, nghỉ dài giữa set"
        case .endurance: return "Cardio và tập nhiều reps, nghỉ ngắn"
        case .health: return "Vận động đều đặn cho tim mạch và chuyển hoá"
        }
    }

    var systemImage: String {
        switch self {
        case .cut: return "arrow.down.right.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .bulk: return "arrow.up.right.circle.fill"
        case .strength: return "dumbbell.fill"
        case .endurance: return "figure.run"
        case .health: return "heart.fill"
        }
    }

    /// Chỉ ba mục tiêu về thành phần cơ thể mới quyết định mức calo;
    /// các mục tiêu còn lại ảnh hưởng tới cách tập chứ không phải lượng ăn.
    var affectsCalories: Bool {
        switch self {
        case .cut, .maintain, .bulk: return true
        default: return false
        }
    }

    /// Mức thâm hụt/thặng dư mặc định so với TDEE, tính theo phần trăm.
    /// Nguồn: khuyến nghị 10-20% của ACSM cho thay đổi cân nặng bền vững.
    var defaultCalorieOffsetRatio: Double {
        switch self {
        case .cut: return -0.18
        case .bulk: return 0.12
        default: return 0
        }
    }
}

// MARK: - Tập luyện

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, calves, core, fullBody, cardio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: return "Ngực"
        case .back: return "Lưng"
        case .shoulders: return "Vai"
        case .biceps: return "Tay trước"
        case .triceps: return "Tay sau"
        case .forearms: return "Cẳng tay"
        case .quads: return "Đùi trước"
        case .hamstrings: return "Đùi sau"
        case .glutes: return "Mông"
        case .calves: return "Bắp chân"
        case .core: return "Bụng"
        case .fullBody: return "Toàn thân"
        case .cardio: return "Cardio"
        }
    }

    /// Nhóm cơ lớn cần tần suất tối thiểu 2 buổi/tuần (khuyến nghị ACSM).
    var isMajor: Bool {
        switch self {
        case .chest, .back, .shoulders, .quads, .hamstrings, .glutes, .core:
            return true
        default:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .cardio: return "heart.fill"
        case .core: return "figure.core.training"
        default: return "figure.strengthtraining.traditional"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .barbell: return "Đòn tạ"
        case .dumbbell: return "Tạ đơn"
        case .machine: return "Máy"
        case .cable: return "Cáp"
        case .bodyweight: return "Tự trọng"
        case .kettlebell: return "Tạ ấm"
        case .band: return "Dây kháng lực"
        case .other: return "Khác"
        }
    }
}

/// Kiểu set. Ảnh hưởng tới cách ghi log và tới hệ số tiêu hao năng lượng.
enum SetType: String, Codable, CaseIterable, Identifiable {
    case normal, dropSet, superSet, warmup, amrap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal set"
        case .dropSet: return "Drop set"
        case .superSet: return "Super set"
        case .warmup: return "Khởi động"
        case .amrap: return "AMRAP"
        }
    }

    var shortLabel: String {
        switch self {
        case .normal: return "N"
        case .dropSet: return "DS"
        case .superSet: return "SS"
        case .warmup: return "W"
        case .amrap: return "A"
        }
    }

    /// Drop set và super set dồn khối lượng vào ít thời gian nghỉ hơn nên
    /// chi phí năng lượng trên mỗi phút cao hơn set thường.
    var intensityFactor: Double {
        switch self {
        case .normal: return 1.0
        case .dropSet: return 1.25
        case .superSet: return 1.30
        case .warmup: return 0.6
        case .amrap: return 1.15
        }
    }
}

enum SessionStatus: String, Codable {
    case planned, inProgress, completed, skipped

    var label: String {
        switch self {
        case .planned: return "Đã lên lịch"
        case .inProgress: return "Đang tập"
        case .completed: return "Hoàn thành"
        case .skipped: return "Bỏ buổi"
        }
    }
}

// MARK: - Dinh dưỡng

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack, preWorkout, postWorkout

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Bữa sáng"
        case .lunch: return "Bữa trưa"
        case .dinner: return "Bữa tối"
        case .snack: return "Bữa phụ"
        case .preWorkout: return "Trước tập"
        case .postWorkout: return "Sau tập"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        case .preWorkout: return "bolt.fill"
        case .postWorkout: return "arrow.clockwise.heart.fill"
        }
    }
}

// MARK: - Bệnh nền

/// Các bệnh nền phổ biến có khuyến nghị vận động rõ ràng trong y văn.
enum HealthConditionKind: String, Codable, CaseIterable, Identifiable {
    // Tim mạch – chuyển hoá
    case hypertension, coronaryArteryDisease, heartFailure
    case prediabetes, type2Diabetes, dyslipidemia, obesity, fattyLiver, gout
    // Hô hấp
    case asthma, copd, sleepApnea
    // Cơ xương khớp
    case lowBackPain, kneeOsteoarthritis, osteoporosis, rheumatoidArthritis
    case shoulderImpingement, plantarFasciitis, scoliosis
    // Nội tiết – sinh sản
    case hypothyroidism, hyperthyroidism, pcos
    // Khác
    case anemia, chronicKidneyDisease, gerd, irritableBowel
    case varicoseVeins, migraine, depressionAnxiety, insomnia, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hypertension: return "Tăng huyết áp"
        case .coronaryArteryDisease: return "Bệnh mạch vành"
        case .heartFailure: return "Suy tim"
        case .prediabetes: return "Tiền đái tháo đường"
        case .fattyLiver: return "Gan nhiễm mỡ"
        case .gout: return "Gout"
        case .copd: return "Bệnh phổi tắc nghẽn mạn tính (COPD)"
        case .sleepApnea: return "Ngưng thở khi ngủ"
        case .osteoporosis: return "Loãng xương"
        case .rheumatoidArthritis: return "Viêm khớp dạng thấp"
        case .shoulderImpingement: return "Hội chứng chạm vai"
        case .plantarFasciitis: return "Viêm cân gan chân"
        case .scoliosis: return "Vẹo cột sống"
        case .hyperthyroidism: return "Cường giáp"
        case .chronicKidneyDisease: return "Bệnh thận mạn"
        case .irritableBowel: return "Hội chứng ruột kích thích"
        case .varicoseVeins: return "Suy giãn tĩnh mạch chân"
        case .migraine: return "Đau nửa đầu"
        case .depressionAnxiety: return "Trầm cảm / lo âu"
        case .type2Diabetes: return "Đái tháo đường type 2"
        case .dyslipidemia: return "Rối loạn mỡ máu"
        case .obesity: return "Béo phì"
        case .lowBackPain: return "Đau thắt lưng mạn"
        case .kneeOsteoarthritis: return "Thoái hoá khớp gối"
        case .asthma: return "Hen phế quản"
        case .hypothyroidism: return "Suy giáp"
        case .pcos: return "Buồng trứng đa nang (PCOS)"
        case .anemia: return "Thiếu máu"
        case .gerd: return "Trào ngược dạ dày"
        case .insomnia: return "Mất ngủ"
        case .none: return "Không có"
        }
    }
}

// MARK: - Mùa / khí hậu

enum ThermalSeason: String, Codable {
    case hot, warm, temperate, cool, cold

    var label: String {
        switch self {
        case .hot: return "Nóng"
        case .warm: return "Ấm"
        case .temperate: return "Ôn hoà"
        case .cool: return "Mát"
        case .cold: return "Lạnh"
        }
    }

    var systemImage: String {
        switch self {
        case .hot: return "thermometer.sun.fill"
        case .warm: return "sun.max.fill"
        case .temperate: return "cloud.sun.fill"
        case .cool: return "wind"
        case .cold: return "thermometer.snowflake"
        }
    }
}
