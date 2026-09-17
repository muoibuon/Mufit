import Foundation
import SwiftData

/// Một bài tập trong thư viện. Nạp từ wger.de hoặc từ bộ seed đóng gói sẵn.
@Model
final class Exercise {
    @Attribute(.unique) var slug: String
    var name: String
    var primaryMuscleRaw: String
    var secondaryMuscleRaws: [String]
    var equipmentRaw: String
    /// MET — chi phí năng lượng chuẩn hoá, theo Compendium of Physical Activities (Ainsworth 2011).
    var met: Double
    var instructions: String
    var sourceName: String
    var sourceURL: String
    var isCustom: Bool

    init(
        slug: String,
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        equipment: Equipment = .barbell,
        met: Double = 5.0,
        instructions: String = "",
        sourceName: String = "",
        sourceURL: String = "",
        isCustom: Bool = false
    ) {
        self.slug = slug
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMuscleRaws = secondaryMuscles.map(\.rawValue)
        self.equipmentRaw = equipment.rawValue
        self.met = met
        self.instructions = instructions
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.isCustom = isCustom
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .fullBody }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMuscleRaws.compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryMuscleRaws = newValue.map(\.rawValue) }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }
}

/// Một buổi tập trên lịch. Người dùng tự setup thủ công từng bài.
@Model
final class WorkoutSession {
    var date: Date
    var title: String
    var statusRaw: String
    var startedAt: Date?
    var finishedAt: Date?
    var note: String
    /// Nhiệt độ ghi nhận lúc tập, dùng để hiệu chỉnh calo theo mùa.
    var recordedTemperatureC: Double?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise] = []

    init(
        date: Date = .now,
        title: String = "Buổi tập",
        status: SessionStatus = .planned,
        note: String = ""
    ) {
        self.date = date
        self.title = title
        self.statusRaw = status.rawValue
        self.note = note
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var orderedExercises: [SessionExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var allSets: [SetLog] {
        orderedExercises.flatMap(\.orderedSets)
    }

    var durationMinutes: Double {
        guard let start = startedAt, let end = finishedAt else { return 0 }
        return end.timeIntervalSince(start) / 60
    }

    /// Tổng khối lượng nâng (kg × reps) của các set đã hoàn thành.
    var completedVolumeKg: Double {
        allSets.filter(\.isCompleted).reduce(0) { $0 + $1.volumeKg }
    }

    var plannedRepTotal: Int {
        allSets.reduce(0) { $0 + $1.targetReps }
    }

    var actualRepTotal: Int {
        allSets.reduce(0) { $0 + ($1.actualReps ?? 0) }
    }

    /// Hiệu suất buổi tập = reps thực tế / reps dự kiến.
    var completionRate: Double {
        guard plannedRepTotal > 0 else { return 0 }
        return Double(actualRepTotal) / Double(plannedRepTotal)
    }

    var musclesWorked: Set<MuscleGroup> {
        var set = Set<MuscleGroup>()
        for ex in orderedExercises {
            guard let e = ex.exercise else { continue }
            set.insert(e.primaryMuscle)
            e.secondaryMuscles.forEach { set.insert($0) }
        }
        return set
    }
}

/// Một bài tập cụ thể bên trong buổi tập.
@Model
final class SessionExercise {
    var order: Int
    /// Các bài cùng `supersetGroup` (khác nil) được thực hiện nối tiếp không nghỉ.
    var supersetGroup: Int?
    var restSeconds: Int
    var note: String

    var exercise: Exercise?
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.sessionExercise)
    var sets: [SetLog] = []

    init(order: Int, exercise: Exercise?, restSeconds: Int = 90, supersetGroup: Int? = nil, note: String = "") {
        self.order = order
        self.exercise = exercise
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
        self.note = note
    }

    var orderedSets: [SetLog] {
        sets.sorted { $0.index < $1.index }
    }

    var isFullyLogged: Bool {
        !sets.isEmpty && sets.allSatisfy(\.isCompleted)
    }
}

/// Một set. `targetReps` là dự kiến khi setup, `actualReps` là con số thật khi tập xong.
@Model
final class SetLog {
    var index: Int
    var setTypeRaw: String
    var targetReps: Int
    var actualReps: Int?
    var weightKg: Double
    /// Với drop set: các mức tạ giảm dần sau set chính.
    var dropWeights: [Double]
    var dropReps: [Int]
    var rpe: Double?
    var isCompleted: Bool
    var completedAt: Date?

    var sessionExercise: SessionExercise?

    init(
        index: Int,
        setType: SetType = .normal,
        targetReps: Int = 10,
        weightKg: Double = 20,
        dropWeights: [Double] = [],
        dropReps: [Int] = []
    ) {
        self.index = index
        self.setTypeRaw = setType.rawValue
        self.targetReps = targetReps
        self.weightKg = weightKg
        self.dropWeights = dropWeights
        self.dropReps = dropReps
        self.isCompleted = false
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .normal }
        set { setTypeRaw = newValue.rawValue }
    }

    /// Tổng kg nâng được, cộng cả phần drop nếu có.
    var volumeKg: Double {
        let base = Double(actualReps ?? 0) * weightKg
        let drops = zip(dropWeights, dropReps).reduce(0.0) { $0 + $1.0 * Double($1.1) }
        return base + drops
    }

    /// Ước lượng 1RM theo công thức Epley — dùng để theo dõi tiến bộ sức mạnh.
    var estimatedOneRepMax: Double {
        guard let reps = actualReps, reps > 0, weightKg > 0 else { return 0 }
        return weightKg * (1 + Double(reps) / 30)
    }
}
