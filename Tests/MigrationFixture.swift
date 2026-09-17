import Foundation
import SwiftData

/// Compile with the pre-change model files, then run MusclePersistenceTests on this store.
@main
struct MigrationFixture {
    @MainActor static func main() throws {
        let schema = Schema([UserProfile.self, BodyMeasurement.self, Exercise.self, WorkoutSession.self,
                             SessionExercise.self, SetLog.self, FoodItem.self, MealEntry.self, FoodPortion.self,
                             Supplement.self, HydrationLog.self, SunExposureLog.self, WeatherSnapshot.self, MovementLog.self])
        let config = ModelConfiguration(schema: schema, url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let container = try ModelContainer(for: schema, configurations: config)
        container.mainContext.insert(UserProfile(name: "Migration fixture"))
        let exercise = Exercise(slug: "fixture-custom", name: "Fixture exercise", primaryMuscle: .calves, isCustom: true)
        container.mainContext.insert(exercise)
        let session = WorkoutSession(status: .completed)
        container.mainContext.insert(session)
        let item = SessionExercise(order: 0, exercise: exercise, note: "Legacy exercise")
        item.session = session
        container.mainContext.insert(item)
        try container.mainContext.save()
        print("Created legacy migration fixture")
    }
}
