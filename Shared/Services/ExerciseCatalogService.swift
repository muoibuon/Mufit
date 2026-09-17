import Foundation

/// Tải thư viện bài tập từ wger.de — cơ sở dữ liệu bài tập mã nguồn mở,
/// nội dung do cộng đồng đóng góp và kiểm duyệt, giấy phép CC-BY-SA.
/// API công khai, không cần khoá.
struct ExerciseCatalogService {

    struct RemoteExercise {
        var slug: String
        var name: String
        var primaryMuscle: MuscleGroup
        var secondaryMuscles: [MuscleGroup]
        var equipment: Equipment
        var met: Double
        var instructions: String
    }

    private struct Page: Decodable {
        let results: [Item]
    }

    private struct Item: Decodable {
        struct Category: Decodable { let id: Int; let name: String }
        struct Muscle: Decodable { let id: Int }
        struct Equip: Decodable { let id: Int }
        struct Translation: Decodable {
            let language: Int
            let name: String?
            let description: String?
        }
        let uuid: String
        let category: Category?
        let muscles: [Muscle]
        let muscles_secondary: [Muscle]
        let equipment: [Equip]
        let translations: [Translation]?
    }

    /// Tải tối đa `limit` bài tập tiếng Anh từ wger.
    func fetchCatalog(limit: Int = 200) async throws -> [RemoteExercise] {
        var components = URLComponents(string: "https://wger.de/api/v2/exerciseinfo/")!
        components.queryItems = [
            .init(name: "format", value: "json"),
            .init(name: "limit", value: String(limit)),
            .init(name: "language", value: "2")   // 2 = English
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let page = try JSONDecoder().decode(Page.self, from: data)
        return page.results.compactMap(Self.map(_:))
    }

    private static func map(_ item: Item) -> RemoteExercise? {
        let english = item.translations?.first { $0.language == 2 }
        guard let name = english?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        let primary = item.muscles.compactMap { muscleGroup(wgerMuscleID: $0.id) }.first
            ?? categoryMuscle(item.category?.id)
        let secondary = item.muscles_secondary.compactMap { muscleGroup(wgerMuscleID: $0.id) }
        let equipment = item.equipment.compactMap { equipmentKind(wgerID: $0.id) }.first ?? .other

        return RemoteExercise(
            slug: "wger-" + item.uuid,
            name: name,
            primaryMuscle: primary,
            secondaryMuscles: Array(Set(secondary)).filter { $0 != primary },
            equipment: equipment,
            met: metValue(for: primary, equipment: equipment),
            instructions: stripHTML(english?.description ?? "")
        )
    }

    private static func muscleGroup(wgerMuscleID id: Int) -> MuscleGroup? {
        switch id {
        case 1, 13: return .biceps          // Biceps brachii, Brachialis
        case 2, 9: return .shoulders        // Deltoid, Trapezius
        case 4, 3: return .chest            // Pectoralis major, Serratus anterior
        case 5: return .triceps
        case 6, 14: return .core            // Rectus abdominis, Obliques
        case 7, 15: return .calves          // Gastrocnemius, Soleus
        case 8: return .glutes
        case 10: return .quads
        case 11: return .hamstrings
        case 12, 16: return .back           // Lats, Erector spinae
        default: return nil
        }
    }

    private static func categoryMuscle(_ id: Int?) -> MuscleGroup {
        switch id {
        case 8: return .biceps      // Arms
        case 9: return .quads       // Legs
        case 10: return .core       // Abs
        case 11: return .chest
        case 12: return .back
        case 13: return .shoulders
        case 14: return .calves
        default: return .fullBody
        }
    }

    private static func equipmentKind(wgerID id: Int) -> Equipment? {
        switch id {
        case 1, 2: return .barbell
        case 3: return .dumbbell
        case 10: return .kettlebell
        case 7, 4, 6, 8, 9: return .bodyweight
        default: return .other
        }
    }

    /// MET tham chiếu Compendium of Physical Activities (Ainsworth 2011):
    /// tập kháng lực cường độ vừa ≈ 5.0, nặng đa khớp ≈ 6.0, bài đơn khớp nhẹ ≈ 3.5.
    static func metValue(for muscle: MuscleGroup, equipment: Equipment) -> Double {
        switch muscle {
        case .cardio: return 7.0
        case .fullBody: return 6.0
        case .quads, .hamstrings, .glutes: return equipment == .barbell ? 6.0 : 5.0
        case .back, .chest: return equipment == .barbell ? 5.5 : 4.8
        case .shoulders: return 4.5
        case .core: return 3.8
        case .biceps, .triceps, .forearms, .calves: return 3.5
        }
    }

    private static func stripHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
