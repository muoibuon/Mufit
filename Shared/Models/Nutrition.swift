import Foundation
import SwiftData

/// Một món ăn / nguyên liệu trong thư viện, dinh dưỡng quy về 100 g.
@Model
final class FoodItem {
    @Attribute(.unique) var slug: String
    var name: String
    var brand: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double
    var sodiumMgPer100g: Double
    var sugarPer100g: Double
    var sourceName: String
    var isCustom: Bool

    init(
        slug: String,
        name: String,
        brand: String = "",
        caloriesPer100g: Double,
        proteinPer100g: Double = 0,
        carbsPer100g: Double = 0,
        fatPer100g: Double = 0,
        fiberPer100g: Double = 0,
        sodiumMgPer100g: Double = 0,
        sugarPer100g: Double = 0,
        sourceName: String = "",
        isCustom: Bool = false
    ) {
        self.slug = slug
        self.name = name
        self.brand = brand
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sodiumMgPer100g = sodiumMgPer100g
        self.sugarPer100g = sugarPer100g
        self.sourceName = sourceName
        self.isCustom = isCustom
    }
}

/// Một bữa ăn trong ngày.
@Model
final class MealEntry {
    var date: Date
    var slotRaw: String
    var note: String

    @Relationship(deleteRule: .cascade, inverse: \FoodPortion.meal)
    var portions: [FoodPortion] = []

    init(date: Date = .now, slot: MealSlot = .breakfast, note: String = "") {
        self.date = date
        self.slotRaw = slot.rawValue
        self.note = note
    }

    var slot: MealSlot {
        get { MealSlot(rawValue: slotRaw) ?? .snack }
        set { slotRaw = newValue.rawValue }
    }

    var totals: MacroTotals {
        portions.reduce(.zero) { $0 + $1.macros }
    }
}

/// Khẩu phần: món ăn + số gram thực tế.
@Model
final class FoodPortion {
    var grams: Double
    var food: FoodItem?
    var meal: MealEntry?

    init(grams: Double, food: FoodItem?) {
        self.grams = grams
        self.food = food
    }

    var macros: MacroTotals {
        guard let f = food else { return .zero }
        let k = grams / 100
        return MacroTotals(
            calories: f.caloriesPer100g * k,
            protein: f.proteinPer100g * k,
            carbs: f.carbsPer100g * k,
            fat: f.fatPer100g * k,
            fiber: f.fiberPer100g * k,
            sodiumMg: f.sodiumMgPer100g * k,
            sugar: f.sugarPer100g * k
        )
    }
}

struct MacroTotals: Equatable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sodiumMg: Double = 0
    var sugar: Double = 0

    static let zero = MacroTotals()

    static func + (a: MacroTotals, b: MacroTotals) -> MacroTotals {
        MacroTotals(
            calories: a.calories + b.calories,
            protein: a.protein + b.protein,
            carbs: a.carbs + b.carbs,
            fat: a.fat + b.fat,
            fiber: a.fiber + b.fiber,
            sodiumMg: a.sodiumMg + b.sodiumMg,
            sugar: a.sugar + b.sugar
        )
    }
}

/// Thực phẩm bổ sung người dùng đang dùng.
@Model
final class Supplement {
    var name: String
    var ingredients: String
    var servingDescription: String
    var dosagePerDay: Double
    var unit: String
    var timingNote: String
    var startedAt: Date
    var isActive: Bool

    init(
        name: String,
        ingredients: String = "",
        servingDescription: String = "",
        dosagePerDay: Double = 1,
        unit: String = "liều",
        timingNote: String = "",
        startedAt: Date = .now,
        isActive: Bool = true
    ) {
        self.name = name
        self.ingredients = ingredients
        self.servingDescription = servingDescription
        self.dosagePerDay = dosagePerDay
        self.unit = unit
        self.timingNote = timingNote
        self.startedAt = startedAt
        self.isActive = isActive
    }

    /// Tách chuỗi thành phần thành danh sách để đối chiếu với gợi ý.
    var ingredientList: [String] {
        ingredients
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}

@Model
final class HydrationLog {
    var date: Date
    var milliliters: Double

    init(date: Date = .now, milliliters: Double) {
        self.date = date
        self.milliliters = milliliters
    }
}

/// Ghi nhận phơi nắng — đầu vào cho gợi ý vitamin D.
@Model
final class SunExposureLog {
    var date: Date
    var minutes: Double
    var uvIndex: Double
    /// Phần trăm da hở (tay + chân ≈ 25%).
    var skinExposurePercent: Double
    var wasOutdoor: Bool

    init(date: Date = .now, minutes: Double, uvIndex: Double = 6, skinExposurePercent: Double = 25, wasOutdoor: Bool = true) {
        self.date = date
        self.minutes = minutes
        self.uvIndex = uvIndex
        self.skinExposurePercent = skinExposurePercent
        self.wasOutdoor = wasOutdoor
    }
}

/// Snapshot thời tiết theo ngày, cache lại để không gọi API nhiều lần.
@Model
final class WeatherSnapshot {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var meanTempC: Double
    var maxTempC: Double
    var minTempC: Double
    var humidityPercent: Double
    var uvIndexMax: Double
    var latitude: Double
    var longitude: Double

    init(
        dayKey: String,
        date: Date,
        meanTempC: Double,
        maxTempC: Double,
        minTempC: Double,
        humidityPercent: Double,
        uvIndexMax: Double,
        latitude: Double,
        longitude: Double
    ) {
        self.dayKey = dayKey
        self.date = date
        self.meanTempC = meanTempC
        self.maxTempC = maxTempC
        self.minTempC = minTempC
        self.humidityPercent = humidityPercent
        self.uvIndexMax = uvIndexMax
        self.latitude = latitude
        self.longitude = longitude
    }

    var season: ThermalSeason {
        switch meanTempC {
        case 30...: return .hot
        case 24..<30: return .warm
        case 17..<24: return .temperate
        case 10..<17: return .cool
        default: return .cold
        }
    }
}

/// Ghi nhận di chuyển trong ngày (từ CoreLocation), dùng để hỏi về phơi nắng.
@Model
final class MovementLog {
    var date: Date
    var distanceMeters: Double
    var outdoorMinutes: Double
    var didPromptSun: Bool

    init(date: Date = .now, distanceMeters: Double = 0, outdoorMinutes: Double = 0, didPromptSun: Bool = false) {
        self.date = date
        self.distanceMeters = distanceMeters
        self.outdoorMinutes = outdoorMinutes
        self.didPromptSun = didPromptSun
    }
}
