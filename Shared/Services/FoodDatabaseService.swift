import Foundation

/// Tra cứu thực phẩm từ Open Food Facts — cơ sở dữ liệu thực phẩm mở,
/// dữ liệu dinh dưỡng lấy từ nhãn sản phẩm, giấy phép ODbL.
/// API công khai, không cần khoá; chỉ yêu cầu User-Agent định danh ứng dụng.
struct FoodDatabaseService {

    struct RemoteFood {
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
    }

    private struct SearchResponse: Decodable {
        let products: [Product]
    }

    private struct Product: Decodable {
        let code: String?
        let product_name: String?
        let brands: String?
        let nutriments: Nutriments?
    }

    private struct Nutriments: Decodable {
        let energyKcal: Double?
        let proteins: Double?
        let carbohydrates: Double?
        let fat: Double?
        let fiber: Double?
        let sodium: Double?
        let sugars: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal = "energy-kcal_100g"
            case proteins = "proteins_100g"
            case carbohydrates = "carbohydrates_100g"
            case fat = "fat_100g"
            case fiber = "fiber_100g"
            case sodium = "sodium_100g"
            case sugars = "sugars_100g"
        }
    }

    static let userAgent = "Mufit/1.0 (iOS; https://github.com/fitcore)"

    func search(term: String, limit: Int = 25) async throws -> [RemoteFood] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            .init(name: "search_terms", value: trimmed),
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: String(limit)),
            .init(name: "fields", value: "code,product_name,brands,nutriments")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.products.compactMap(Self.map(_:))
    }

    private static func map(_ p: Product) -> RemoteFood? {
        guard
            let name = p.product_name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
            let n = p.nutriments,
            let kcal = n.energyKcal, kcal > 0
        else { return nil }

        return RemoteFood(
            slug: "off-" + (p.code ?? UUID().uuidString),
            name: name,
            brand: p.brands ?? "",
            caloriesPer100g: kcal,
            proteinPer100g: n.proteins ?? 0,
            carbsPer100g: n.carbohydrates ?? 0,
            fatPer100g: n.fat ?? 0,
            fiberPer100g: n.fiber ?? 0,
            sodiumMgPer100g: (n.sodium ?? 0) * 1000,   // OFF trả về gram
            sugarPer100g: n.sugars ?? 0
        )
    }
}

/// So khớp lượng dinh dưỡng đã nạp với mục tiêu, sinh gợi ý "còn thiếu gì".
enum NutritionGapAdvisor {

    struct Gap: Identifiable {
        var id = UUID()
        var nutrient: String
        var consumed: Double
        var target: Double
        var unit: String
        var suggestion: String

        var ratio: Double { target > 0 ? consumed / target : 0 }
        var isDeficit: Bool { ratio < 0.85 }
        var isExcess: Bool { ratio > 1.15 }
    }

    static func gaps(consumed: MacroTotals, target: MacroTotals) -> [Gap] {
        var result: [Gap] = []

        result.append(Gap(
            nutrient: "Calo",
            consumed: consumed.calories,
            target: target.calories,
            unit: "kcal",
            suggestion: consumed.calories < target.calories * 0.85
                ? "Còn thiếu \(Int(target.calories - consumed.calories)) kcal. Thiếu năng lượng kéo dài làm giảm hiệu suất tập và mất cơ."
                : "Đã vượt \(Int(consumed.calories - target.calories)) kcal so với mục tiêu."
        ))

        result.append(Gap(
            nutrient: "Đạm",
            consumed: consumed.protein,
            target: target.protein,
            unit: "gram",
            suggestion: "Còn thiếu \(Int(max(0, target.protein - consumed.protein))) gram đạm ≈ \(Int(max(0, target.protein - consumed.protein) / 25 * 100)) gram ức gà, hoặc \(max(1, Int(max(0, target.protein - consumed.protein) / 6))) quả trứng, hoặc 1-2 muỗng whey."
        ))

        result.append(Gap(
            nutrient: "Carb",
            consumed: consumed.carbs,
            target: target.carbs,
            unit: "gram",
            suggestion: "Carb là nhiên liệu chính cho buổi tập cường độ cao. Ưu tiên gạo lứt, yến mạch, khoai lang, trái cây."
        ))

        result.append(Gap(
            nutrient: "Béo",
            consumed: consumed.fat,
            target: target.fat,
            unit: "gram",
            suggestion: "Giữ mỡ tối thiểu ~0.8 gram/kg cân nặng để bảo vệ nội tiết. Nguồn tốt: cá béo, dầu ô liu, các loại hạt."
        ))

        result.append(Gap(
            nutrient: "Chất xơ",
            consumed: consumed.fiber,
            target: target.fiber,
            unit: "gram",
            suggestion: "Thiếu xơ ảnh hưởng tiêu hoá và cảm giác no. Thêm rau xanh, đậu, ngũ cốc nguyên cám."
        ))

        result.append(Gap(
            nutrient: "Natri",
            consumed: consumed.sodiumMg,
            target: target.sodiumMg,
            unit: "mg",
            suggestion: consumed.sodiumMg > target.sodiumMg
                ? "Vượt ngưỡng WHO (2000-2300 mg/ngày). Natri cao liên quan tới tăng huyết áp."
                : "Trong ngưỡng khuyến nghị."
        ))

        return result
    }

    /// Gợi ý supplement dựa trên khoảng trống dinh dưỡng và bệnh nền.
    static func supplementSuggestions(
        gaps: [Gap],
        existing: [Supplement],
        conditions: [HealthConditionKind]
    ) -> [String] {
        var out: [String] = []
        let have = Set(existing.flatMap(\.ingredientList) + existing.map { $0.name.lowercased() })

        func lacks(_ keys: [String]) -> Bool {
            !keys.contains { k in have.contains { $0.contains(k) } }
        }

        if let p = gaps.first(where: { $0.nutrient == "Đạm" }), p.isDeficit, lacks(["whey", "protein", "đạm", "casein"]) {
            out.append("Whey protein — cách rẻ và tiện nhất để bù phần đạm còn thiếu mỗi ngày.")
        }
        if let f = gaps.first(where: { $0.nutrient == "Chất xơ" }), f.isDeficit, lacks(["fiber", "psyllium", "xơ"]) {
            out.append("Chất xơ hoà tan (psyllium) — chỉ dùng khi không thể tăng rau củ trong bữa ăn.")
        }
        if lacks(["creatine", "creatin"]) {
            out.append("Creatine monohydrate 3-5 gram/ngày — supplement có bằng chứng mạnh nhất cho sức mạnh và khối cơ (ISSN Position Stand 2017).")
        }
        if conditions.contains(.dyslipidemia) || conditions.contains(.hypertension), lacks(["omega", "epa", "dha", "fish oil", "dầu cá"]) {
            out.append("Omega-3 (EPA/DHA) — hỗ trợ giảm triglyceride và huyết áp ở liều 2-3 gram/ngày.")
        }
        if conditions.contains(.anemia), lacks(["iron", "sắt", "ferrous"]) {
            out.append("Sắt — chỉ bổ sung khi có xét nghiệm ferritin thấp và theo chỉ định bác sĩ.")
        }
        if conditions.contains(.kneeOsteoarthritis), lacks(["collagen", "glucosamine"]) {
            out.append("Collagen peptide 10-15 gram kèm vitamin C — bằng chứng ở mức vừa phải cho đau khớp.")
        }

        return out
    }
}
