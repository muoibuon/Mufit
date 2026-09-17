import Foundation

enum MuscleTrainingGuidance {
    struct Source: Identifiable {
        var id: String { url }
        var title: String
        var url: String
    }
    struct Note: Identifiable {
        var id: String { title }
        var title: String
        var text: String
        var source: Source?
    }

    static let acsm = Source(title: "ACSM · Khuyến nghị tập kháng lực 2026", url: "https://acsm.org/resistance-training-guidelines-update-2026/")
    static let cdc = Source(title: "CDC · Vận động khi có bệnh mạn tính", url: "https://www.cdc.gov/physical-activity-basics/guidelines/chronic-health-conditions-and-disabilities.html")
    static let diabetes = Source(title: "NIDDK · Sống khỏe với đái tháo đường", url: "https://www.niddk.nih.gov/health-information/diabetes/overview/healthy-living-with-diabetes")
    static let kidney = Source(title: "NIDDK · Dinh dưỡng trong bệnh thận mạn", url: "https://www.niddk.nih.gov/health-information/kidney-disease/chronic-kidney-disease-ckd/healthy-eating-adults-chronic-kidney-disease")
    static let heart = Source(title: "AHA · Vận động và huyết áp", url: "https://www.heart.org/en/health-topics/high-blood-pressure/changes-you-can-make-to-manage-high-blood-pressure/getting-active-to-control-high-blood-pressure")
    static let joints = Source(title: "NICE NG226 · Thoái hóa khớp", url: "https://www.nice.org.uk/guidance/ng226/chapter/Recommendations")
    static let anatomy = Source(title: "OpenStax · Hệ cơ, chương 11", url: "https://openstax.org/books/anatomy-and-physiology/pages/11-chapter-review")

    static func anatomyDescription(_ muscle: MuscleGroup) -> String {
        switch muscle {
        case .chest: return "Cơ ngực lớn: khép và đẩy cánh tay ra trước."
        case .back: return "Nhóm lưng gồm cơ thang, cơ lưng rộng và cơ dựng sống; hỗ trợ kéo, kiểm soát bả vai và giữ thân mình."
        case .shoulders: return "Cơ delta có bó trước, giữa và sau, tham gia nâng và di chuyển cánh tay."
        case .biceps: return "Cơ nhị đầu cánh tay và nhóm gấp khuỷu; tham gia kéo và gấp tay."
        case .triceps: return "Cơ tam đầu cánh tay: duỗi khuỷu, tham gia động tác đẩy."
        case .forearms: return "Nhóm gấp/duỗi cổ tay và ngón tay, tham gia lực nắm."
        case .quads: return "Cơ tứ đầu đùi: duỗi gối; tham gia đứng lên, squat và bước lên."
        case .hamstrings: return "Nhóm cơ đùi sau: gấp gối và tham gia duỗi hông."
        case .glutes: return "Nhóm cơ mông: duỗi, dạng hông và giữ ổn định vùng chậu."
        case .calves: return "Cơ bụng chân và cơ dép nằm phía sau cẳng chân, tham gia nhón gót."
        case .core: return "Nhóm bụng gồm cơ thẳng bụng và các cơ chéo; cùng cơ sâu kiểm soát thân mình."
        default: return "Nhóm vận động tổng hợp."
        }
    }

    static func notes(muscle: MuscleGroup, profile: UserProfile, measurement: BodyMeasurement?, now: Date) -> [Note] {
        var notes = [Note(title: "Tần suất tham khảo", text: "Với người trưởng thành khỏe mạnh, tập các nhóm cơ lớn ít nhất 2 ngày mỗi tuần. Chia lịch theo khả năng hồi phục và tổng khối lượng tập. Dấu xanh chỉ xác nhận đã tập, không xác nhận đã hồi phục hoặc đủ liều tập.", source: acsm)]
        if profile.age < 18 {
            notes[0] = Note(title: "Hồ sơ dưới 18 tuổi", text: "Khuyến nghị ACSM ở đây dành cho người trưởng thành. Cần chương trình phù hợp tuổi, kỹ thuật và sự hướng dẫn của người có chuyên môn; app không đặt chỉ tiêu tập cá nhân cho hồ sơ này.", source: acsm)
        } else if profile.conditions.filter({ $0 != .none }).isEmpty && profile.goals.contains(.bulk) {
            notes.append(Note(title: "Mục tiêu tăng cơ", text: "ACSM 2026 nêu khoảng 10 hiệp/nhóm cơ/tuần như một mức tham khảo cho tăng cơ ở người trưởng thành khỏe mạnh. Tăng dần theo khả năng; hiệp hỗ trợ được hiển thị riêng vì không tương đương hiệp trực tiếp.", source: acsm))
        }
        if let m = measurement {
            var parts = ["Số đo ngày \(m.date.formatted(date: .abbreviated, time: .omitted))."]
            if m.weightKg > 0, profile.heightCm > 0 {
                let bmi = m.weightKg / pow(profile.heightCm / 100, 2)
                parts.append(String(format: "BMI %.1f.", bmi))
                if let muscle = m.skeletalMuscleKg, muscle > 0, muscle <= m.weightKg {
                    parts.append(String(format: "Cơ xương %.1f kg (%.1f%% cân nặng).", muscle, muscle / m.weightKg * 100))
                }
                if let waist = m.waistCm, waist > 0 {
                    parts.append(String(format: "Eo/chiều cao %.2f.", waist / profile.heightCm))
                }
            }
            if let fat = m.bodyFatPercent, (0...100).contains(fat) { parts.append(String(format: "Mỡ %.1f%%.", fat)) }
            if let water = m.bodyWaterPercent, (0...100).contains(water) { parts.append(String(format: "Nước %.1f%%.", water)) }
            parts.append("Các chỉ số toàn thân không cho biết kích thước hoặc sức mạnh của riêng vùng \(muscle.label.lowercased()). Tỉ lệ nước, cơ và mỡ không phải các phần độc lập để cộng thành 100%. App chưa có số đo từng vùng hoặc xét nghiệm vi chất, nên không tự tăng tần suất tập từ các tỉ lệ này.")
            if now.timeIntervalSince(m.date) > 30 * 86400 { parts.append("Số đo đã hơn 30 ngày; nên cập nhật trước khi điều chỉnh kế hoạch.") }
            notes.append(Note(title: "Bối cảnh cơ thể của bạn", text: parts.joined(separator: " "), source: nil))
        } else {
            notes.append(Note(title: "Chưa có số đo cơ thể", text: "Thêm cân nặng, chiều cao và các số đo bạn có ở mục Cơ thể. Gợi ý hiện tại chỉ mang tính chung; không ước đoán mỡ, nước hoặc khối cơ còn thiếu.", source: nil))
        }
        let conditions = profile.conditions.filter { $0 != .none }
        if !conditions.isEmpty {
            notes.append(Note(title: "Điều chỉnh theo bệnh nền", text: "Đã khai báo: \(conditions.map(\.label).joined(separator: ", ")). Chọn mức vận động phù hợp khả năng và trao đổi với người điều trị về loại bài, cường độ, tần suất. App chưa biết mức độ bệnh, thuốc hoặc triệu chứng hiện tại để đặt liều tập riêng.", source: cdc))
        }
        if conditions.contains(.hypertension) {
            notes.append(Note(title: "Huyết áp và buổi tập", text: "Khởi động, tăng tải từ từ và thở đều khi nâng tạ. Tránh nín thở vì có thể làm tăng huyết áp. Tuân theo giới hạn mà người điều trị đã hướng dẫn.", source: heart))
        }
        if conditions.contains(.type2Diabetes) {
            notes.append(Note(title: "Đường huyết", text: "Insulin và một số thuốc như sulfonylurea có thể gây hạ đường huyết khi tập. Trao đổi về theo dõi đường huyết và bữa ăn quanh buổi tập; không tự đổi thuốc theo dấu xanh.", source: diabetes))
        }
        if conditions.contains(.chronicKidneyDisease) {
            notes.append(Note(title: "Đạm, nước và bệnh thận", text: "Lượng đạm và dịch cần được cá nhân hóa theo chức năng thận và điều trị. Không tự tăng đạm hoặc uống thêm nước chỉ vì vừa tập một vùng cơ hay thấy tỉ lệ nước thấp.", source: kidney))
        }
        if conditions.contains(.kneeOsteoarthritis), [.quads, .hamstrings, .glutes, .calves].contains(muscle) {
            notes.append(Note(title: "Vùng chân và khớp gối", text: "NICE khuyến nghị bài tập điều trị phù hợp từng người, gồm tăng sức mạnh cơ tại chỗ. Chọn biên độ và mức tải theo khả năng; cân nhắc hướng dẫn vật lý trị liệu khi cần.", source: joints))
        }
        return notes
    }
}
