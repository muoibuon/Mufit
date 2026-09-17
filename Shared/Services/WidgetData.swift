import Foundation
import SwiftData

/// Số liệu tóm tắt cho widget. Tính từ cùng một store mà app đang dùng.
enum WidgetData {

    struct NutritionSnapshot {
        var consumedCalories: Double = 0
        var targetCalories: Double = 2000
        var protein: Double = 0
        var proteinTarget: Double = 0
        var carbs: Double = 0
        var carbsTarget: Double = 0
        var fat: Double = 0
        var fatTarget: Double = 0
        var mealCount: Int = 0

        var progress: Double { targetCalories > 0 ? consumedCalories / targetCalories : 0 }
        var isOver: Bool { progress > 1 }
        var remaining: Double { max(0, targetCalories - consumedCalories) }

        static let placeholder = NutritionSnapshot(
            consumedCalories: 1450, targetCalories: 2400,
            protein: 92, proteinTarget: 150,
            carbs: 160, carbsTarget: 260,
            fat: 48, fatTarget: 70,
            mealCount: 3
        )
    }

    struct HydrationSnapshot {
        var consumedML: Double = 0
        var targetML: Double = 2500
        var seasonNote: String = ""

        var progress: Double { targetML > 0 ? consumedML / targetML : 0 }
        /// Uống dư dưới 1 lít không đáng kể, không cần báo đỏ.
        var isOver: Bool { consumedML - targetML > 1000 }
        var remaining: Double { max(0, targetML - consumedML) }

        static let placeholder = HydrationSnapshot(consumedML: 1330, targetML: 3100, seasonNote: "Trời ấm 28°C")
    }

    // MARK: - Truy vấn

    private static func todayProfileBundle(_ context: ModelContext) -> (UserProfile, BodyMeasurement?, WeatherSnapshot?) {
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first ?? UserProfile()

        var measureDescriptor = FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        measureDescriptor.fetchLimit = 1
        let measurement = (try? context.fetch(measureDescriptor))?.first

        let key = WeatherStore.dayKey(for: .now)
        var weatherDescriptor = FetchDescriptor<WeatherSnapshot>(predicate: #Predicate { $0.dayKey == key })
        weatherDescriptor.fetchLimit = 1
        let weather = (try? context.fetch(weatherDescriptor))?.first

        return (profile, measurement, weather)
    }

    static func nutrition(context: ModelContext) -> NutritionSnapshot {
        let (profile, measurement, weather) = todayProfileBundle(context)
        let (start, end) = DayRange.today()

        let meals = (try? context.fetch(FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))) ?? []

        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))) ?? []

        let bodyWeight = measurement?.weightKg ?? 70
        let workoutCalories = sessions
            .filter { $0.statusRaw == SessionStatus.completed.rawValue || $0.statusRaw == SessionStatus.inProgress.rawValue }
            .reduce(0.0) { $0 + EnergyCalculator.caloriesForSession($1, bodyWeightKg: bodyWeight, weather: weather) }

        let target = EnergyCalculator.dailyCalorieTarget(
            profile: profile, measurement: measurement, weather: weather, workoutCalories: workoutCalories
        )
        let macros = EnergyCalculator.macroTargets(calories: target, profile: profile, measurement: measurement)
        let consumed = meals.reduce(MacroTotals.zero) { $0 + $1.totals }

        return NutritionSnapshot(
            consumedCalories: consumed.calories,
            targetCalories: target,
            protein: consumed.protein, proteinTarget: macros.protein,
            carbs: consumed.carbs, carbsTarget: macros.carbs,
            fat: consumed.fat, fatTarget: macros.fat,
            mealCount: meals.count
        )
    }

    static func hydration(context: ModelContext) -> HydrationSnapshot {
        let (profile, measurement, weather) = todayProfileBundle(context)
        let (start, end) = DayRange.today()

        let logs = (try? context.fetch(FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))) ?? []

        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))) ?? []

        let trainingMinutes = sessions.reduce(0.0) { partial, s in
            s.durationMinutes > 0 ? partial + s.durationMinutes : partial + Double(s.allSets.count) * 2.5
        }

        let rec = HydrationAdvisor.recommend(
            weightKg: measurement?.weightKg ?? 70,
            sex: profile.sex,
            trainingMinutes: trainingMinutes,
            weather: weather
        )

        let note: String
        if let w = weather {
            note = "\(w.season.label) \(Int(w.meanTempC))°C"
        } else {
            note = ""
        }

        return HydrationSnapshot(
            consumedML: logs.reduce(0) { $0 + $1.milliliters },
            targetML: rec.totalML,
            seasonNote: note
        )
    }
}
