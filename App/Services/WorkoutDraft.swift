import Foundation

struct DraftSet: Identifiable, Equatable {
    var id = UUID()
    var setType: SetType = .normal
    var targetReps: Int = 10
    var weightKg: Double = 20
    var dropWeights: [Double] = []
    var dropReps: [Int] = []
    var actualReps: Int?
    var rpe: Double?
    var isCompleted = false
    var completedAt: Date?

    func makeSetLog(index: Int) -> SetLog {
        let log = SetLog(index: index, setType: setType, targetReps: targetReps,
                         weightKg: weightKg, dropWeights: dropWeights, dropReps: dropReps)
        log.actualReps = actualReps
        log.rpe = rpe
        log.isCompleted = isCompleted
        log.completedAt = completedAt
        return log
    }
}

struct DraftExercise: Identifiable, Equatable {
    var id = UUID()
    var exercise: Exercise?
    var order: Int
    var restSeconds: Int = 90
    var supersetGroup: Int?
    var note: String = ""
    var anatomyTargetRaws: [String]?
    var sets: [DraftSet] = [DraftSet(), DraftSet(), DraftSet()]

    var displayName: String { exercise?.name ?? "Bài tập" }

    init(exercise: Exercise?, order: Int) {
        self.exercise = exercise
        self.order = order
    }

    init(from se: SessionExercise) {
        self.exercise = se.exercise
        self.order = se.order
        self.restSeconds = se.restSeconds
        self.supersetGroup = se.supersetGroup
        self.note = se.note
        self.anatomyTargetRaws = se.anatomyTargetRaws
        self.sets = se.orderedSets.map {
            DraftSet(
                setType: $0.setType,
                targetReps: $0.targetReps,
                weightKg: $0.weightKg,
                dropWeights: $0.dropWeights,
                dropReps: $0.dropReps,
                actualReps: $0.actualReps,
                rpe: $0.rpe,
                isCompleted: $0.isCompleted,
                completedAt: $0.completedAt
            )
        }
    }

    /// Reuse a plan without carrying completed results into a new session.
    init(repeating se: SessionExercise, order: Int) {
        self.init(from: se)
        self.order = order
        self.sets = sets.map { previous in
            var planned = previous
            planned.id = UUID()
            planned.actualReps = nil
            planned.rpe = nil
            planned.isCompleted = false
            planned.completedAt = nil
            return planned
        }
    }

    static func == (a: DraftExercise, b: DraftExercise) -> Bool { a.id == b.id && a.sets == b.sets }
}
