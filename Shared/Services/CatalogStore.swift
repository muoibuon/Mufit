import Foundation
import SwiftData

/// Nạp dữ liệu ban đầu và đồng bộ thư viện từ internet vào SwiftData.
@MainActor
final class CatalogStore: ObservableObject {

    enum SyncState: Equatable {
        case idle
        case syncing(String)
        case success(String)
        case failure(String)
    }

    @Published var exerciseSync: SyncState = .idle
    @Published var foodSearchState: SyncState = .idle

    private let exerciseService = ExerciseCatalogService()
    private let foodService = FoodDatabaseService()

    // MARK: - Seed

    private struct SeedExercise: Decodable {
        let slug: String
        let name: String
        let primaryMuscle: String
        let secondaryMuscles: [String]
        let equipment: String
        let met: Double
        let instructions: String
        let sourceName: String
        let sourceURL: String
    }

    private struct SeedFood: Decodable {
        let slug: String
        let name: String
        let brand: String
        let caloriesPer100g: Double
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let fiberPer100g: Double
        let sodiumMgPer100g: Double
        let sugarPer100g: Double
        let sourceName: String
    }

    /// Chạy một lần khi mở app: đảm bảo có thư viện dùng offline ngay.
    func seedIfNeeded(context: ModelContext) {
        seedExercisesIfNeeded(context: context)
        seedFoodsIfNeeded(context: context)
        ensureProfile(context: context)
    }

    /// Bổ sung bài tập còn thiếu. Chạy theo slug chứ không chỉ khi kho rỗng,
    /// để người đã dùng app từ trước cũng nhận được dữ liệu mới.
    private func seedExercisesIfNeeded(context: ModelContext) {
        guard
            let url = Bundle.main.url(forResource: "seed_exercises", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let items = try? JSONDecoder().decode([SeedExercise].self, from: data)
        else { return }

        let existing = Set(((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map(\.slug))

        for i in items where !existing.contains(i.slug) {
            let ex = Exercise(
                slug: i.slug,
                name: i.name,
                primaryMuscle: MuscleGroup(rawValue: i.primaryMuscle) ?? .fullBody,
                secondaryMuscles: i.secondaryMuscles.compactMap(MuscleGroup.init(rawValue:)),
                equipment: Equipment(rawValue: i.equipment) ?? .other,
                met: i.met,
                instructions: i.instructions,
                sourceName: i.sourceName,
                sourceURL: i.sourceURL
            )
            context.insert(ex)
        }
        try? context.save()
    }

    /// Tương tự với thư viện món ăn.
    private func seedFoodsIfNeeded(context: ModelContext) {
        guard
            let url = Bundle.main.url(forResource: "seed_foods", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let items = try? JSONDecoder().decode([SeedFood].self, from: data)
        else { return }

        let existing = Set(((try? context.fetch(FetchDescriptor<FoodItem>())) ?? []).map(\.slug))

        for i in items where !existing.contains(i.slug) {
            context.insert(FoodItem(
                slug: i.slug,
                name: i.name,
                brand: i.brand,
                caloriesPer100g: i.caloriesPer100g,
                proteinPer100g: i.proteinPer100g,
                carbsPer100g: i.carbsPer100g,
                fatPer100g: i.fatPer100g,
                fiberPer100g: i.fiberPer100g,
                sodiumMgPer100g: i.sodiumMgPer100g,
                sugarPer100g: i.sugarPer100g,
                sourceName: i.sourceName
            ))
        }
        try? context.save()
    }

    private func ensureProfile(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard count == 0 else { return }
        context.insert(UserProfile())
        try? context.save()
    }

    // MARK: - Đồng bộ từ internet

    /// Tải thêm bài tập từ wger.de, bỏ qua bài đã có.
    func syncExercises(context: ModelContext) async {
        exerciseSync = .syncing("Đang tải thư viện bài tập từ wger.de…")
        do {
            let remote = try await exerciseService.fetchCatalog(limit: 250)
            let existing = Set((try? context.fetch(FetchDescriptor<Exercise>()))?.map(\.slug) ?? [])

            var added = 0
            for r in remote where !existing.contains(r.slug) {
                context.insert(Exercise(
                    slug: r.slug,
                    name: r.name,
                    primaryMuscle: r.primaryMuscle,
                    secondaryMuscles: r.secondaryMuscles,
                    equipment: r.equipment,
                    met: r.met,
                    instructions: r.instructions,
                    sourceName: "wger.de (CC-BY-SA)",
                    sourceURL: "https://wger.de"
                ))
                added += 1
            }
            try context.save()
            exerciseSync = .success("Đã thêm \(added) bài tập mới từ wger.de.")
        } catch {
            exerciseSync = .failure("Không tải được: \(error.localizedDescription). Thư viện offline vẫn dùng bình thường.")
        }
    }

    /// Tìm món ăn trên Open Food Facts và lưu vào thư viện cục bộ.
    func searchAndImportFoods(term: String, context: ModelContext) async -> [FoodItem] {
        foodSearchState = .syncing("Đang tìm \"\(term)\"…")
        do {
            let remote = try await foodService.search(term: term)
            guard !remote.isEmpty else {
                foodSearchState = .failure("Không tìm thấy kết quả nào cho \"\(term)\".")
                return []
            }

            let existing = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
            let bySlug = Dictionary(existing.map { ($0.slug, $0) }, uniquingKeysWith: { a, _ in a })

            var result: [FoodItem] = []
            for r in remote {
                if let found = bySlug[r.slug] {
                    result.append(found)
                    continue
                }
                let item = FoodItem(
                    slug: r.slug,
                    name: r.name,
                    brand: r.brand,
                    caloriesPer100g: r.caloriesPer100g,
                    proteinPer100g: r.proteinPer100g,
                    carbsPer100g: r.carbsPer100g,
                    fatPer100g: r.fatPer100g,
                    fiberPer100g: r.fiberPer100g,
                    sodiumMgPer100g: r.sodiumMgPer100g,
                    sugarPer100g: r.sugarPer100g,
                    sourceName: "Open Food Facts (ODbL)"
                )
                context.insert(item)
                result.append(item)
            }
            try context.save()
            foodSearchState = .success("Tìm thấy \(result.count) kết quả.")
            return result
        } catch {
            foodSearchState = .failure("Lỗi mạng: \(error.localizedDescription)")
            return []
        }
    }
}
