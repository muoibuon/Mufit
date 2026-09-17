import Foundation
import SwiftData

@main
struct MusclePersistenceTests {
    @MainActor static func main() throws {
        let schema = Schema([UserProfile.self, BodyMeasurement.self, Exercise.self, WorkoutSession.self,
                             SessionExercise.self, SetLog.self, FoodItem.self, MealEntry.self, FoodPortion.self,
                             Supplement.self, HydrationLog.self, SunExposureLog.self, WeatherSnapshot.self, MovementLog.self])
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let configuration = ModelConfiguration(schema: schema, url: url)
        func write() throws {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(container)
            let profile = try context.fetch(FetchDescriptor<UserProfile>()).first!
            assert(profile.name == "Migration fixture", "Existing profile must survive migration")
            assert(profile.muscleNotesJSON == nil)
            let legacyItem = try context.fetch(FetchDescriptor<SessionExercise>()).first!
            assert(legacyItem.note == "Legacy exercise" && legacyItem.anatomyTargetRaws == nil)
            legacyItem.anatomyTargetRaws = [AnatomicalMuscle.tibialisAnterior.rawValue]
            try profile.setMuscleNote("Vai: tập trong biên độ thoải mái", for: .shoulders)
            try profile.setMuscleNote("Ngực: 3 hiệp", for: .chest)
            try profile.setMuscleNote("Ghi chú cơ chày trước", forKey: AnatomicalMuscle.tibialisAnterior.noteKey)
            try context.save()
        }
        try write()
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first!
        assert(profile.muscleNote(for: .shoulders) == "Vai: tập trong biên độ thoải mái")
        assert(profile.muscleNote(for: .chest) == "Ngực: 3 hiệp")
        assert(profile.muscleNote(forKey: AnatomicalMuscle.tibialisAnterior.noteKey) == "Ghi chú cơ chày trước")
        assert(tryFetchTargets(context) == [AnatomicalMuscle.tibialisAnterior.rawValue])
        try profile.setMuscleNote("", for: .chest)
        assert(profile.muscleNote(for: .chest).isEmpty && !profile.muscleNote(for: .shoulders).isEmpty)
        try context.save()

        let payload = BackupPayload.snapshot(from: context, deviceName: "Test")
        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(BackupPayload.self, from: encoded)
        let restored = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try decoded.restore(into: restored.mainContext)
        let restoredProfile = try restored.mainContext.fetch(FetchDescriptor<UserProfile>()).first!
        assert(restoredProfile.muscleNote(for: .shoulders) == profile.muscleNote(for: .shoulders))
        assert(restoredProfile.muscleNote(forKey: AnatomicalMuscle.tibialisAnterior.noteKey) == "Ghi chú cơ chày trước")
        assert(tryFetchTargets(restored.mainContext) == [AnatomicalMuscle.tibialisAnterior.rawValue])
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        var legacyProfile = legacy["profile"] as! [String: Any]
        legacyProfile.removeValue(forKey: "muscleNotesJSON")
        legacy["profile"] = legacyProfile
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        let legacyPayload = try JSONDecoder().decode(BackupPayload.self, from: legacyData)
        assert(legacyPayload.profile?.muscleNotesJSON == nil)

        let exercise = Exercise(slug: "test-press", name: "Press", primaryMuscle: .chest, secondaryMuscles: [.triceps])
        let session = WorkoutSession(date: Date.now.addingTimeInterval(-10 * 86400), status: .completed)
        session.finishedAt = .now
        let item = SessionExercise(order: 0, exercise: exercise)
        let real = SetLog(index: 0); real.actualReps = 8; real.isCompleted = true
        let warmup = SetLog(index: 1, setType: .warmup); warmup.actualReps = 8; warmup.isCompleted = true
        let skipped = SetLog(index: 2); skipped.actualReps = 0; skipped.isCompleted = true
        let undone = SetLog(index: 3); undone.actualReps = 8
        item.sets = [real, warmup, skipped, undone]
        session.exercises = [item]
        real.rpe = 8.5
        real.completedAt = Date.now.addingTimeInterval(-120)
        var edited = DraftExercise(from: item)
        edited.anatomyTargetRaws = [AnatomicalMuscle.pectoralisMajor.rawValue]
        let preserved = edited.sets[0].makeSetLog(index: 0)
        assert(preserved.isCompleted && preserved.actualReps == 8)
        assert(preserved.rpe == real.rpe && preserved.completedAt == real.completedAt)
        let newSet = DraftSet().makeSetLog(index: 1)
        assert(!newSet.isCompleted && newSet.actualReps == nil && newSet.completedAt == nil)
        let repeated = DraftExercise(repeating: item, order: 2)
        assert(repeated.order == 2 && repeated.sets.count == item.sets.count)
        assert(repeated.sets[0].targetReps == real.targetReps && repeated.sets[0].weightKg == real.weightKg)
        assert(repeated.sets.allSatisfy { !$0.isCompleted && $0.actualReps == nil && $0.rpe == nil && $0.completedAt == nil })
        print("PASS: editing anatomical targets preserves actual set results; new sets remain incomplete")
        let records = WeeklyMuscleTracker.records(from: [session])
        assert(records[0].date == session.finishedAt! && records[0].activities[0].workingSets == 1)
        item.anatomyTargetRaws = [AnatomicalMuscle.tibialisAnterior.rawValue, "unknown-future-muscle"]
        let precise = AnatomicalTrainingTracker.records(from: [session])
        assert(precise[0].activities[0].targets.direct == [.tibialisAnterior])
        item.anatomyTargetRaws = []
        assert(AnatomicalTrainingTracker.records(from: [session])[0].activities[0].targets.direct.isEmpty)

        profile.conditions = [.chronicKidneyDisease, .type2Diabetes]
        profile.goals = [.bulk]
        let notes = MuscleTrainingGuidance.notes(muscle: .chest, profile: profile, measurement: nil, now: .now)
        assert(notes.contains { $0.source?.url == MuscleTrainingGuidance.kidney.url })
        assert(notes.contains { $0.source?.url == MuscleTrainingGuidance.diabetes.url })
        assert(!notes.contains { $0.title == "Mục tiêu tăng cơ" })
        print("PASS: legacy SwiftData migration, saved notes across reopening, per-muscle delete, backup/restore, old backup decoding, logged-set filtering, completion date, condition-aware guidance")
    }

    @MainActor private static func tryFetchTargets(_ context: ModelContext) -> [String]? {
        try! context.fetch(FetchDescriptor<SessionExercise>()).first!.anatomyTargetRaws
    }
}
