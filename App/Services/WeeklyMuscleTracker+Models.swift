import Foundation

extension WeeklyMuscleTracker {
    static func records(from sessions: [WorkoutSession]) -> [Record] {
        sessions.map { session in
            Record(date: session.finishedAt ?? session.date, completed: session.status == .completed,
                   activities: session.exercises.compactMap { item in
                guard let exercise = item.exercise else { return nil }
                let sets = item.sets.filter {
                    $0.isCompleted && $0.setType != .warmup && (($0.actualReps ?? 0) > 0 || $0.dropReps.contains { $0 > 0 })
                }
                return Activity(primary: exercise.primaryMuscle, secondary: exercise.secondaryMuscles,
                                workingSets: sets.count)
            })
        }
    }
}

extension AnatomicalTrainingTracker {
    static func records(from sessions: [WorkoutSession]) -> [Record] {
        sessions.map { session in
            Record(date: session.finishedAt ?? session.date, completed: session.status == .completed,
                   activities: session.exercises.compactMap { item in
                guard let exercise = item.exercise else { return nil }
                let sets = item.sets.filter {
                    $0.isCompleted && $0.setType != .warmup && (($0.actualReps ?? 0) > 0 || $0.dropReps.contains { $0 > 0 })
                }
                let targets = item.anatomyTargetRaws.map { Targets(direct: Set($0.compactMap(AnatomicalMuscle.init(rawValue:)))) }
                    ?? Self.targets(slug: exercise.slug, isCustom: exercise.isCustom)
                return Activity(targets: targets, sets: sets.count)
            })
        }
    }
}
