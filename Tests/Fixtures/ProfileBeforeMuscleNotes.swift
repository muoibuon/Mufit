import Foundation
import SwiftData

/// Hồ sơ người dùng. App chỉ giữ một bản ghi duy nhất.
@Model
final class UserProfile {
    var name: String
    var sexRaw: String
    var birthDate: Date
    var heightCm: Double
    var activityLevelRaw: String
    var goalRaw: String
    /// Danh sách mục tiêu. Thêm mới chứ không thay `goalRaw` để store cũ vẫn mở được.
    var goalRaws: [String] = []
    /// Mức offset calo do người dùng tự đặt; nil = dùng mặc định của mục tiêu.
    var customCalorieOffset: Double?
    var conditionRaws: [String]
    var createdAt: Date

    init(
        name: String = "",
        sex: BiologicalSex = .male,
        birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now,
        heightCm: Double = 170,
        activityLevel: ActivityLevel = .moderate,
        goals: [GoalType] = [.maintain],
        conditions: [HealthConditionKind] = []
    ) {
        self.name = name
        self.sexRaw = sex.rawValue
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.activityLevelRaw = activityLevel.rawValue
        self.goalRaw = goals.first?.rawValue ?? GoalType.maintain.rawValue
        self.goalRaws = goals.map(\.rawValue)
        self.customCalorieOffset = nil
        self.conditionRaws = conditions.map(\.rawValue)
        self.createdAt = .now
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var goals: [GoalType] {
        get {
            let parsed = goalRaws.compactMap(GoalType.init(rawValue:))
            // Hồ sơ tạo từ bản cũ chỉ có một mục tiêu duy nhất.
            return parsed.isEmpty ? [GoalType(rawValue: goalRaw) ?? .maintain] : parsed
        }
        set {
            goalRaws = newValue.map(\.rawValue)
            goalRaw = newValue.first?.rawValue ?? GoalType.maintain.rawValue
        }
    }

    /// Mục tiêu quyết định mức calo. Chọn cả giảm mỡ lẫn tăng cơ nghĩa là
    /// muốn tái cấu trúc cơ thể (recomp) — ăn quanh mức duy trì, đạm cao.
    var primaryCompositionGoal: GoalType {
        let composition = goals.filter(\.affectsCalories)
        if composition.contains(.cut) && composition.contains(.bulk) { return .maintain }
        return composition.first ?? .maintain
    }

    var isRecomposition: Bool {
        goals.contains(.cut) && goals.contains(.bulk)
    }

    var goalSummary: String {
        goals.map(\.label).joined(separator: " · ")
    }

    var conditions: [HealthConditionKind] {
        get { conditionRaws.compactMap(HealthConditionKind.init(rawValue:)) }
        set { conditionRaws = newValue.map(\.rawValue) }
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 25
    }

    var calorieOffsetRatio: Double {
        if let custom = customCalorieOffset { return custom }
        // Recomp: giữ quanh mức duy trì, hụt nhẹ để mỡ giảm dần mà vẫn đủ ăn để tăng cơ.
        if isRecomposition { return -0.04 }
        return primaryCompositionGoal.defaultCalorieOffsetRatio
    }
}

/// Một lần đo thành phần cơ thể (cân InBody, thước kẹp mỡ, hoặc nhập tay).
@Model
final class BodyMeasurement {
    var date: Date
    var weightKg: Double
    var bodyFatPercent: Double?
    var skeletalMuscleKg: Double?
    var bodyWaterPercent: Double?
    var boneMassKg: Double?
    var visceralFatRating: Double?
    var waistCm: Double?
    var note: String

    init(
        date: Date = .now,
        weightKg: Double,
        bodyFatPercent: Double? = nil,
        skeletalMuscleKg: Double? = nil,
        bodyWaterPercent: Double? = nil,
        boneMassKg: Double? = nil,
        visceralFatRating: Double? = nil,
        waistCm: Double? = nil,
        note: String = ""
    ) {
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.skeletalMuscleKg = skeletalMuscleKg
        self.bodyWaterPercent = bodyWaterPercent
        self.boneMassKg = boneMassKg
        self.visceralFatRating = visceralFatRating
        self.waistCm = waistCm
        self.note = note
    }

    /// Khối nạc (lean body mass) — đầu vào của công thức Katch-McArdle.
    var leanMassKg: Double? {
        guard let bf = bodyFatPercent else { return skeletalMuscleKg }
        return weightKg * (1 - bf / 100)
    }

    var fatMassKg: Double? {
        guard let bf = bodyFatPercent else { return nil }
        return weightKg * bf / 100
    }
}
