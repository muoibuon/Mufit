import Foundation
import SwiftData

/// Ảnh chụp toàn bộ dữ liệu người dùng, dạng có thể mã hoá thành JSON.
///
/// Thư viện bài tập và món ăn mặc định **không** nằm trong đây — chúng giống nhau ở
/// mọi máy và tự nạp lại khi mở app. Chỉ những mục người dùng tự thêm mới được sao lưu,
/// và các buổi tập / bữa ăn tham chiếu tới chúng qua `slug`.
struct BackupPayload: Codable {

    static let currentVersion = 1

    var version: Int = BackupPayload.currentVersion
    var createdAt: Date = .now
    var deviceName: String = ""

    var profile: ProfileDTO?
    var measurements: [MeasurementDTO] = []
    var customExercises: [ExerciseDTO] = []
    var sessions: [SessionDTO] = []
    var customFoods: [FoodDTO] = []
    var meals: [MealDTO] = []
    var supplements: [SupplementDTO] = []
    var hydration: [HydrationDTO] = []
    var sunLogs: [SunDTO] = []

    // MARK: - DTO

    struct ProfileDTO: Codable {
        var name: String
        var sexRaw: String
        var birthDate: Date
        var heightCm: Double
        var activityLevelRaw: String
        var goalRaws: [String]
        var customCalorieOffset: Double?
        var conditionRaws: [String]
        var muscleNotesJSON: String? = nil
    }

    struct MeasurementDTO: Codable {
        var date: Date
        var weightKg: Double
        var bodyFatPercent: Double?
        var skeletalMuscleKg: Double?
        var bodyWaterPercent: Double?
        var boneMassKg: Double?
        var visceralFatRating: Double?
        var waistCm: Double?
        var note: String
    }

    struct ExerciseDTO: Codable {
        var slug: String
        var name: String
        var primaryMuscleRaw: String
        var secondaryMuscleRaws: [String]
        var equipmentRaw: String
        var met: Double
        var instructions: String
        var sourceName: String
        var sourceURL: String
    }

    struct SetDTO: Codable {
        var index: Int
        var setTypeRaw: String
        var targetReps: Int
        var actualReps: Int?
        var weightKg: Double
        var dropWeights: [Double]
        var dropReps: [Int]
        var rpe: Double?
        var isCompleted: Bool
        var completedAt: Date?
    }

    struct SessionExerciseDTO: Codable {
        var order: Int
        var exerciseSlug: String?
        var restSeconds: Int
        var supersetGroup: Int?
        var note: String
        var sets: [SetDTO]
        var anatomyTargetRaws: [String]? = nil
    }

    struct SessionDTO: Codable {
        var date: Date
        var title: String
        var statusRaw: String
        var startedAt: Date?
        var finishedAt: Date?
        var note: String
        var recordedTemperatureC: Double?
        var exercises: [SessionExerciseDTO]
    }

    struct FoodDTO: Codable {
        var slug: String
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
    }

    struct PortionDTO: Codable {
        var grams: Double
        var foodSlug: String?
    }

    struct MealDTO: Codable {
        var date: Date
        var slotRaw: String
        var note: String
        var portions: [PortionDTO]
    }

    struct SupplementDTO: Codable {
        var name: String
        var ingredients: String
        var servingDescription: String
        var dosagePerDay: Double
        var unit: String
        var timingNote: String
        var startedAt: Date
        var isActive: Bool
    }

    struct HydrationDTO: Codable {
        var date: Date
        var milliliters: Double
    }

    struct SunDTO: Codable {
        var date: Date
        var minutes: Double
        var uvIndex: Double
        var skinExposurePercent: Double
        var wasOutdoor: Bool
    }
}

// MARK: - Chụp ảnh dữ liệu hiện có

extension BackupPayload {

    static func snapshot(from context: ModelContext, deviceName: String) -> BackupPayload {
        var payload = BackupPayload()
        payload.deviceName = deviceName

        if let p = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first {
            payload.profile = ProfileDTO(
                name: p.name, sexRaw: p.sexRaw, birthDate: p.birthDate, heightCm: p.heightCm,
                activityLevelRaw: p.activityLevelRaw,
                goalRaws: p.goals.map(\.rawValue),
                customCalorieOffset: p.customCalorieOffset,
                conditionRaws: p.conditionRaws,
                muscleNotesJSON: p.muscleNotesJSON
            )
        }

        payload.measurements = ((try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []).map {
            MeasurementDTO(date: $0.date, weightKg: $0.weightKg, bodyFatPercent: $0.bodyFatPercent,
                           skeletalMuscleKg: $0.skeletalMuscleKg, bodyWaterPercent: $0.bodyWaterPercent,
                           boneMassKg: $0.boneMassKg, visceralFatRating: $0.visceralFatRating,
                           waistCm: $0.waistCm, note: $0.note)
        }

        payload.customExercises = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter(\.isCustom)
            .map {
                ExerciseDTO(slug: $0.slug, name: $0.name, primaryMuscleRaw: $0.primaryMuscleRaw,
                            secondaryMuscleRaws: $0.secondaryMuscleRaws, equipmentRaw: $0.equipmentRaw,
                            met: $0.met, instructions: $0.instructions,
                            sourceName: $0.sourceName, sourceURL: $0.sourceURL)
            }

        payload.sessions = ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).map { s in
            SessionDTO(
                date: s.date, title: s.title, statusRaw: s.statusRaw,
                startedAt: s.startedAt, finishedAt: s.finishedAt, note: s.note,
                recordedTemperatureC: s.recordedTemperatureC,
                exercises: s.orderedExercises.map { se in
                    SessionExerciseDTO(
                        order: se.order, exerciseSlug: se.exercise?.slug,
                        restSeconds: se.restSeconds, supersetGroup: se.supersetGroup, note: se.note,
                        sets: se.orderedSets.map { set in
                            SetDTO(index: set.index, setTypeRaw: set.setTypeRaw,
                                   targetReps: set.targetReps, actualReps: set.actualReps,
                                   weightKg: set.weightKg, dropWeights: set.dropWeights,
                                   dropReps: set.dropReps, rpe: set.rpe,
                                   isCompleted: set.isCompleted, completedAt: set.completedAt)
                        }, anatomyTargetRaws: se.anatomyTargetRaws)
                })
        }

        payload.customFoods = ((try? context.fetch(FetchDescriptor<FoodItem>())) ?? [])
            .filter { $0.isCustom || $0.slug.hasPrefix("off-") }
            .map {
                FoodDTO(slug: $0.slug, name: $0.name, brand: $0.brand,
                        caloriesPer100g: $0.caloriesPer100g, proteinPer100g: $0.proteinPer100g,
                        carbsPer100g: $0.carbsPer100g, fatPer100g: $0.fatPer100g,
                        fiberPer100g: $0.fiberPer100g, sodiumMgPer100g: $0.sodiumMgPer100g,
                        sugarPer100g: $0.sugarPer100g, sourceName: $0.sourceName)
            }

        payload.meals = ((try? context.fetch(FetchDescriptor<MealEntry>())) ?? []).map { m in
            MealDTO(date: m.date, slotRaw: m.slotRaw, note: m.note,
                    portions: m.portions.map { PortionDTO(grams: $0.grams, foodSlug: $0.food?.slug) })
        }

        payload.supplements = ((try? context.fetch(FetchDescriptor<Supplement>())) ?? []).map {
            SupplementDTO(name: $0.name, ingredients: $0.ingredients,
                          servingDescription: $0.servingDescription, dosagePerDay: $0.dosagePerDay,
                          unit: $0.unit, timingNote: $0.timingNote,
                          startedAt: $0.startedAt, isActive: $0.isActive)
        }

        payload.hydration = ((try? context.fetch(FetchDescriptor<HydrationLog>())) ?? []).map {
            HydrationDTO(date: $0.date, milliliters: $0.milliliters)
        }

        payload.sunLogs = ((try? context.fetch(FetchDescriptor<SunExposureLog>())) ?? []).map {
            SunDTO(date: $0.date, minutes: $0.minutes, uvIndex: $0.uvIndex,
                   skinExposurePercent: $0.skinExposurePercent, wasOutdoor: $0.wasOutdoor)
        }

        return payload
    }

    // MARK: - Ghi đè dữ liệu cục bộ

    /// Thay toàn bộ dữ liệu người dùng bằng bản sao lưu. Thư viện mặc định giữ nguyên.
    func restore(into context: ModelContext) throws {
        for session in (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [] { context.delete(session) }
        for meal in (try? context.fetch(FetchDescriptor<MealEntry>())) ?? [] { context.delete(meal) }
        for m in (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? [] { context.delete(m) }
        for s in (try? context.fetch(FetchDescriptor<Supplement>())) ?? [] { context.delete(s) }
        for h in (try? context.fetch(FetchDescriptor<HydrationLog>())) ?? [] { context.delete(h) }
        for s in (try? context.fetch(FetchDescriptor<SunExposureLog>())) ?? [] { context.delete(s) }
        try context.save()

        // Bài tập và món ăn tự thêm: chèn lại nếu máy này chưa có.
        var exerciseBySlug = Dictionary(
            ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.slug, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        for dto in customExercises where exerciseBySlug[dto.slug] == nil {
            let ex = Exercise(
                slug: dto.slug, name: dto.name,
                primaryMuscle: MuscleGroup(rawValue: dto.primaryMuscleRaw) ?? .fullBody,
                secondaryMuscles: dto.secondaryMuscleRaws.compactMap(MuscleGroup.init(rawValue:)),
                equipment: Equipment(rawValue: dto.equipmentRaw) ?? .other,
                met: dto.met, instructions: dto.instructions,
                sourceName: dto.sourceName, sourceURL: dto.sourceURL, isCustom: true
            )
            context.insert(ex)
            exerciseBySlug[dto.slug] = ex
        }

        var foodBySlug = Dictionary(
            ((try? context.fetch(FetchDescriptor<FoodItem>())) ?? []).map { ($0.slug, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        for dto in customFoods where foodBySlug[dto.slug] == nil {
            let food = FoodItem(
                slug: dto.slug, name: dto.name, brand: dto.brand,
                caloriesPer100g: dto.caloriesPer100g, proteinPer100g: dto.proteinPer100g,
                carbsPer100g: dto.carbsPer100g, fatPer100g: dto.fatPer100g,
                fiberPer100g: dto.fiberPer100g, sodiumMgPer100g: dto.sodiumMgPer100g,
                sugarPer100g: dto.sugarPer100g, sourceName: dto.sourceName, isCustom: true
            )
            context.insert(food)
            foodBySlug[dto.slug] = food
        }

        if let dto = profile {
            let p = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first ?? {
                let new = UserProfile(); context.insert(new); return new
            }()
            p.name = dto.name
            p.sexRaw = dto.sexRaw
            p.birthDate = dto.birthDate
            p.heightCm = dto.heightCm
            p.activityLevelRaw = dto.activityLevelRaw
            p.goals = dto.goalRaws.compactMap(GoalType.init(rawValue:))
            p.customCalorieOffset = dto.customCalorieOffset
            p.conditionRaws = dto.conditionRaws
            p.muscleNotesJSON = dto.muscleNotesJSON
        }

        for dto in measurements {
            context.insert(BodyMeasurement(
                date: dto.date, weightKg: dto.weightKg, bodyFatPercent: dto.bodyFatPercent,
                skeletalMuscleKg: dto.skeletalMuscleKg, bodyWaterPercent: dto.bodyWaterPercent,
                boneMassKg: dto.boneMassKg, visceralFatRating: dto.visceralFatRating,
                waistCm: dto.waistCm, note: dto.note))
        }

        for dto in sessions {
            let session = WorkoutSession(date: dto.date, title: dto.title,
                                         status: SessionStatus(rawValue: dto.statusRaw) ?? .planned,
                                         note: dto.note)
            session.startedAt = dto.startedAt
            session.finishedAt = dto.finishedAt
            session.recordedTemperatureC = dto.recordedTemperatureC
            context.insert(session)

            for seDTO in dto.exercises {
                let se = SessionExercise(
                    order: seDTO.order,
                    exercise: seDTO.exerciseSlug.flatMap { exerciseBySlug[$0] },
                    restSeconds: seDTO.restSeconds,
                    supersetGroup: seDTO.supersetGroup,
                    note: seDTO.note
                )
                se.session = session
                se.anatomyTargetRaws = seDTO.anatomyTargetRaws
                context.insert(se)

                for setDTO in seDTO.sets {
                    let set = SetLog(index: setDTO.index,
                                     setType: SetType(rawValue: setDTO.setTypeRaw) ?? .normal,
                                     targetReps: setDTO.targetReps, weightKg: setDTO.weightKg,
                                     dropWeights: setDTO.dropWeights, dropReps: setDTO.dropReps)
                    set.actualReps = setDTO.actualReps
                    set.rpe = setDTO.rpe
                    set.isCompleted = setDTO.isCompleted
                    set.completedAt = setDTO.completedAt
                    set.sessionExercise = se
                    context.insert(set)
                }
            }
        }

        for dto in meals {
            let meal = MealEntry(date: dto.date,
                                 slot: MealSlot(rawValue: dto.slotRaw) ?? .snack,
                                 note: dto.note)
            context.insert(meal)
            for pDTO in dto.portions {
                let portion = FoodPortion(grams: pDTO.grams,
                                          food: pDTO.foodSlug.flatMap { foodBySlug[$0] })
                portion.meal = meal
                context.insert(portion)
            }
        }

        for dto in supplements {
            context.insert(Supplement(name: dto.name, ingredients: dto.ingredients,
                                      servingDescription: dto.servingDescription,
                                      dosagePerDay: dto.dosagePerDay, unit: dto.unit,
                                      timingNote: dto.timingNote, startedAt: dto.startedAt,
                                      isActive: dto.isActive))
        }

        for dto in hydration {
            context.insert(HydrationLog(date: dto.date, milliliters: dto.milliliters))
        }

        for dto in sunLogs {
            context.insert(SunExposureLog(date: dto.date, minutes: dto.minutes,
                                          uvIndex: dto.uvIndex,
                                          skinExposurePercent: dto.skinExposurePercent,
                                          wasOutdoor: dto.wasOutdoor))
        }

        try context.save()
    }

    var summary: String {
        "\(sessions.count) buổi tập · \(meals.count) bữa ăn · \(measurements.count) lần đo"
    }
}
