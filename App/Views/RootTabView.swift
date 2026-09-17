import SwiftUI
import SwiftData

struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tag(AppRouter.Tab.today)
                .tabItem { Label("Hôm nay", systemImage: "sun.horizon.fill") }

            TrainingCalendarView()
                .tag(AppRouter.Tab.calendar)
                .tabItem { Label("Lịch tập", systemImage: "calendar") }

            NutritionView()
                .tag(AppRouter.Tab.nutrition)
                .tabItem { Label("Ăn uống", systemImage: "fork.knife") }

            BodyView()
                .tag(AppRouter.Tab.body)
                .tabItem { Label("Cơ thể", systemImage: "figure.stand") }

            InsightsView()
                .tag(AppRouter.Tab.insights)
                .tabItem { Label("Phân tích", systemImage: "chart.bar.xaxis") }
        }
        .tint(.brand)
    }
}

/// Gom mọi số liệu của một ngày về một chỗ — dùng chung cho Today, Ăn uống và Phân tích.
struct DayEnergyContext {
    var profile: UserProfile
    var latestMeasurement: BodyMeasurement?
    var weather: WeatherSnapshot?
    var sessions: [WorkoutSession]
    var meals: [MealEntry]

    var bodyWeight: Double { latestMeasurement?.weightKg ?? 70 }

    var workoutCalories: Double {
        sessions
            .filter { $0.status == .completed || $0.status == .inProgress }
            .reduce(0) { $0 + EnergyCalculator.caloriesForSession($1, bodyWeightKg: bodyWeight, weather: weather) }
    }

    var plannedWorkoutCalories: Double {
        sessions
            .filter { $0.status == .planned }
            .reduce(0) { $0 + EnergyCalculator.caloriesForSession($1, bodyWeightKg: bodyWeight, weather: weather) }
    }

    var restingEnergy: Double {
        EnergyCalculator.restingEnergy(profile: profile, measurement: latestMeasurement)
    }

    var tdee: Double {
        EnergyCalculator.totalDailyEnergy(profile: profile, measurement: latestMeasurement, weather: weather)
    }

    var calorieTarget: Double {
        EnergyCalculator.dailyCalorieTarget(
            profile: profile,
            measurement: latestMeasurement,
            weather: weather,
            workoutCalories: workoutCalories
        )
    }

    var macroTarget: MacroTotals {
        EnergyCalculator.macroTargets(calories: calorieTarget, profile: profile, measurement: latestMeasurement)
    }

    var consumed: MacroTotals {
        meals.reduce(.zero) { $0 + $1.totals }
    }

    /// Cân bằng năng lượng: nạp vào − (TDEE + calo tập). Âm = thâm hụt.
    var energyBalance: Double {
        consumed.calories - (tdee + workoutCalories)
    }

    var trainingMinutes: Double {
        sessions.reduce(0) { partial, s in
            if s.durationMinutes > 0 { return partial + s.durationMinutes }
            // Buổi chưa bấm giờ: ước lượng 2.5 phút/set.
            return partial + Double(s.allSets.count) * 2.5
        }
    }
}
