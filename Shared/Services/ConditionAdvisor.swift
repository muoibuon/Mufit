import Foundation

/// Gợi ý luyện tập cho từng bệnh nền, tóm tắt từ khuyến nghị của các hội chuyên ngành.
///
/// ⚠️ Đây là thông tin giáo dục, KHÔNG thay thế chỉ định của bác sĩ.
/// Nguồn tổng hợp: ACSM Exercise is Medicine; ADA Standards of Care;
/// AHA/ACC Hypertension Guideline; NICE guidance cho đau lưng và thoái hoá khớp;
/// GINA cho hen phế quản.
enum ConditionAdvisor {

    struct Guidance: Identifiable {
        var id: String { condition.rawValue }
        var condition: HealthConditionKind
        var summary: String
        var recommended: [String]
        var cautions: [String]
        var preferredMuscles: [MuscleGroup]
        var sourceLabel: String
    }

    static let disclaimer = """
    Thông tin trong mục này mang tính tham khảo, tổng hợp từ khuyến nghị của các hội chuyên \
    ngành. Không dùng để tự chẩn đoán hay thay thế chỉ định điều trị. Hãy hỏi bác sĩ trước khi \
    bắt đầu chương trình tập mới, đặc biệt nếu bạn có bệnh tim mạch, đang dùng thuốc hạ áp, \
    insulin, hoặc mới phẫu thuật.
    """

    static func guidance(for condition: HealthConditionKind) -> Guidance? {
        switch condition {
        case .none:
            return nil

        case .hypertension:
            return Guidance(
                condition: condition,
                summary: "Vận động aerobic đều đặn hạ huyết áp tâm thu trung bình 5-8 mmHg — tương đương một loại thuốc liều thấp.",
                recommended: [
                    "Aerobic cường độ vừa 30 phút/ngày, 5-7 ngày/tuần (đi bộ nhanh, đạp xe, bơi).",
                    "Tập kháng lực 2-3 buổi/tuần với mức tạ vừa, 10-15 reps.",
                    "Bài isometric (plank, wall squat) 4×2 phút cho hiệu quả hạ áp tốt trong các phân tích gộp gần đây.",
                    "Theo dõi huyết áp trước và sau buổi tập trong vài tuần đầu."
                ],
                cautions: [
                    "Tránh nín thở khi gắng sức (nghiệm pháp Valsalva) — làm huyết áp vọt lên đột ngột.",
                    "Tránh nâng tạ rất nặng (>85% 1RM) và tập tới lực kiệt.",
                    "Ngưng tập nếu huyết áp lúc nghỉ > 180/110 mmHg và đi khám.",
                    "Thuốc chẹn beta làm nhịp tim không phản ánh đúng cường độ — dùng thang RPE thay vì nhịp tim."
                ],
                preferredMuscles: [.cardio, .fullBody, .core],
                sourceLabel: "AHA/ACC Hypertension Guideline; ACSM"
            )

        case .type2Diabetes:
            return Guidance(
                condition: condition,
                summary: "Kết hợp aerobic và kháng lực cải thiện HbA1c tốt hơn chỉ làm một loại.",
                recommended: [
                    "150 phút/tuần aerobic cường độ vừa, không nghỉ quá 2 ngày liên tiếp.",
                    "Kháng lực 2-3 buổi/tuần — cơ là nơi tiêu thụ glucose lớn nhất.",
                    "Đi bộ nhẹ 10-15 phút sau bữa ăn giúp cắt đỉnh đường huyết sau ăn.",
                    "Ưu tiên bài compound nhiều nhóm cơ (squat, chèo, đẩy ngực)."
                ],
                cautions: [
                    "Đo đường huyết trước tập; nếu < 100 mg/dL cần ăn nhẹ 15-20 gram carb trước.",
                    "Luôn mang theo nguồn carb nhanh phòng hạ đường huyết, nhất là khi dùng insulin hoặc sulfonylurea.",
                    "Kiểm tra bàn chân sau mỗi buổi nếu có biến chứng thần kinh ngoại biên.",
                    "Nếu có bệnh võng mạc tăng sinh: tránh bài gắng sức tối đa và tư thế dốc ngược đầu."
                ],
                preferredMuscles: [.quads, .back, .chest, .cardio],
                sourceLabel: "ADA Standards of Care; ACSM"
            )

        case .dyslipidemia:
            return Guidance(
                condition: condition,
                summary: "Vận động làm tăng HDL và giảm triglyceride; hiệu quả trên triglyceride thấy rõ nhất.",
                recommended: [
                    "Aerobic 30-60 phút/ngày, 5 ngày/tuần — tổng khối lượng quan trọng hơn cường độ.",
                    "Thêm kháng lực 2 buổi/tuần để giữ khối cơ khi giảm cân.",
                    "Kết hợp giảm mỡ bão hoà và tăng chất xơ hoà tan trong ăn uống."
                ],
                cautions: [
                    "Statin có thể gây đau cơ — báo bác sĩ nếu đau cơ tăng rõ sau khi bắt đầu tập.",
                    "Tăng khối lượng tập từ từ, không quá 10%/tuần."
                ],
                preferredMuscles: [.cardio, .fullBody],
                sourceLabel: "ACSM; AHA"
            )

        case .obesity:
            return Guidance(
                condition: condition,
                summary: "Kháng lực giúp giữ khối nạc trong lúc thâm hụt calo — yếu tố quyết định giảm cân bền vững.",
                recommended: [
                    "Bắt đầu 150 phút/tuần aerobic, tiến tới 250-300 phút/tuần để duy trì cân nặng.",
                    "Kháng lực 2-3 buổi/tuần, ưu tiên máy và bài ổn định trong giai đoạn đầu.",
                    "Bài ít tác động lên khớp: đạp xe, bơi, elliptical, đi bộ dốc.",
                    "Đạm cao (1.6-2.4 gram/kg khối nạc) để bảo toàn cơ."
                ],
                cautions: [
                    "Tránh chạy bộ trên nền cứng khi BMI cao — tải lên khớp gối lớn.",
                    "Chú ý điều nhiệt: khối mỡ cản trở thải nhiệt, dễ quá nhiệt khi trời nóng.",
                    "Tầm soát ngưng thở khi ngủ nếu mệt mỏi ban ngày kéo dài."
                ],
                preferredMuscles: [.fullBody, .cardio, .quads, .back],
                sourceLabel: "ACSM Position Stand; Obesity Society"
            )

        case .lowBackPain:
            return Guidance(
                condition: condition,
                summary: "Vận động là điều trị hàng đầu cho đau lưng mạn — nghỉ ngơi kéo dài làm bệnh nặng thêm.",
                recommended: [
                    "Bài ổn định core: dead bug, bird dog, side plank (bộ ba McGill).",
                    "Tăng dần bài hông: hip thrust, glute bridge — mông yếu làm lưng gánh thay.",
                    "Đi bộ đều đặn hằng ngày.",
                    "Tập giữ cột sống ở tư thế trung tính thay vì gập/ưỡn hết biên độ."
                ],
                cautions: [
                    "Tránh gập lưng có tải lặp lại nhiều lần (sit-up, gập bụng tạ) trong giai đoạn đau cấp.",
                    "Deadlift và squat nặng chỉ quay lại khi hết đau và kỹ thuật ổn định.",
                    "Đi khám ngay nếu có tê yếu chân, rối loạn đại tiểu tiện, sốt hoặc sụt cân không rõ nguyên nhân."
                ],
                preferredMuscles: [.core, .glutes, .hamstrings],
                sourceLabel: "NICE NG59; McGill"
            )

        case .kneeOsteoarthritis:
            return Guidance(
                condition: condition,
                summary: "Mạnh cơ tứ đầu đùi là can thiệp không dùng thuốc hiệu quả nhất cho thoái hoá khớp gối.",
                recommended: [
                    "Leg extension biên độ ngắn, leg press biên độ vừa, mini squat.",
                    "Đạp xe kháng lực nhẹ, yên cao để giảm góc gập gối.",
                    "Bơi và tập dưới nước cho giai đoạn đau nhiều.",
                    "Mạnh cả cơ mông nhỡ để kiểm soát trục chi dưới."
                ],
                cautions: [
                    "Tránh squat sâu có tải, lunge sâu, và chạy đường dài trên nền cứng.",
                    "Đau tăng kéo dài > 2 giờ sau tập là dấu hiệu quá tải — giảm khối lượng buổi sau.",
                    "Không tập qua cơn đau nhói."
                ],
                preferredMuscles: [.quads, .glutes, .hamstrings],
                sourceLabel: "NICE NG226; OARSI"
            )

        case .asthma:
            return Guidance(
                condition: condition,
                summary: "Người hen nên tập — thể lực tốt làm giảm tần suất triệu chứng, miễn là kiểm soát tốt.",
                recommended: [
                    "Khởi động dài 10-15 phút giúp giảm co thắt phế quản do gắng sức.",
                    "Bơi trong hồ thông thoáng và các môn ngắt quãng thường dung nạp tốt.",
                    "Tập thở mũi và bài giãn lồng ngực."
                ],
                cautions: [
                    "Luôn mang thuốc cắt cơn tác dụng nhanh theo người.",
                    "Tránh tập ngoài trời khi lạnh khô, ô nhiễm cao hoặc mùa phấn hoa.",
                    "Hoãn buổi tập khi đang có đợt nhiễm trùng hô hấp."
                ],
                preferredMuscles: [.cardio, .core],
                sourceLabel: "GINA; ACSM"
            )

        case .hypothyroidism:
            return Guidance(
                condition: condition,
                summary: "Chuyển hoá nền giảm nên TDEE tính theo công thức thường cao hơn thực tế.",
                recommended: [
                    "Kháng lực đều đặn để chống mất cơ.",
                    "Aerobic cường độ vừa, tăng tải chậm vì phục hồi chậm hơn.",
                    "Ưu tiên ngủ đủ — thiếu ngủ làm nặng thêm mệt mỏi."
                ],
                cautions: [
                    "Nếu giảm cân chững lại dù ăn đúng mục tiêu, hạ TDEE ước tính 5-10% và xét lại liều thuốc với bác sĩ.",
                    "Canxi, sắt và một số supplement làm giảm hấp thu levothyroxine — uống cách nhau ít nhất 4 giờ."
                ],
                preferredMuscles: [.fullBody],
                sourceLabel: "ATA Guidelines"
            )

        case .pcos:
            return Guidance(
                condition: condition,
                summary: "Kháng lực và aerobic đều cải thiện đề kháng insulin — cơ chế trung tâm của PCOS.",
                recommended: [
                    "Kháng lực 3 buổi/tuần, bài compound.",
                    "120-150 phút/tuần aerobic cường độ vừa đến cao.",
                    "Ưu tiên carb chỉ số đường huyết thấp và đủ chất xơ."
                ],
                cautions: [
                    "Tránh thâm hụt calo quá sâu — gây rối loạn kinh nguyệt nặng thêm.",
                    "Theo dõi chu kỳ để nhận biết đáp ứng."
                ],
                preferredMuscles: [.fullBody, .quads, .back],
                sourceLabel: "International PCOS Guideline 2023"
            )

        case .anemia:
            return Guidance(
                condition: condition,
                summary: "Khả năng vận chuyển oxy giảm nên cùng một bài tập sẽ thấy nặng hơn bình thường.",
                recommended: [
                    "Giảm cường độ, dùng thang RPE thay vì mốc tạ cũ.",
                    "Ưu tiên kháng lực khối lượng thấp, nghỉ dài.",
                    "Tăng thực phẩm giàu sắt kèm vitamin C để tăng hấp thu."
                ],
                cautions: [
                    "Chóng mặt, khó thở bất thường, tim đập nhanh khi gắng sức nhẹ — ngưng tập và đi khám.",
                    "Trà, cà phê và canxi làm giảm hấp thu sắt — tránh uống cùng bữa giàu sắt."
                ],
                preferredMuscles: [.fullBody],
                sourceLabel: "WHO; ACSM"
            )

        case .gerd:
            return Guidance(
                condition: condition,
                summary: "Một số tư thế và thời điểm tập làm trào ngược nặng thêm.",
                recommended: [
                    "Tập cách bữa ăn ít nhất 2-3 giờ.",
                    "Ưu tiên bài đứng hoặc ngồi thẳng thay vì nằm ngửa.",
                    "Cường độ vừa, tăng dần."
                ],
                cautions: [
                    "Hạn chế bài nằm ngửa ngay sau ăn (bench press, crunch).",
                    "Tránh đai lưng quá chặt làm tăng áp lực ổ bụng.",
                    "Uống nước từng ngụm nhỏ thay vì uống nhiều một lúc."
                ],
                preferredMuscles: [.back, .shoulders, .quads],
                sourceLabel: "ACG Clinical Guideline"
            )


        case .coronaryArteryDisease:
            return Guidance(
                condition: condition,
                summary: "Phục hồi chức năng tim bằng vận động giảm tử vong tim mạch 20-30% — hiệu quả ngang nhiều loại thuốc.",
                recommended: [
                    "Bắt đầu trong chương trình phục hồi chức năng tim có giám sát, ít nhất vài tuần đầu.",
                    "Aerobic 20-60 phút, 3-5 ngày/tuần, ở cường độ bác sĩ đã xác định qua nghiệm pháp gắng sức.",
                    "Kháng lực nhẹ đến vừa (40-60% 1RM), 10-15 reps, 2-3 buổi/tuần.",
                    "Khởi động và hạ nhiệt kéo dài 10 phút mỗi đầu buổi."
                ],
                cautions: [
                    "Ngưng ngay và đi cấp cứu nếu đau ngực, khó thở bất thường, choáng váng hoặc nhịp tim không đều.",
                    "Không tập khi chưa được bác sĩ cho phép sau đặt stent hoặc phẫu thuật bắc cầu.",
                    "Tránh gắng sức tối đa, nín thở khi nâng, và tập ngoài trời khi quá nóng hoặc quá lạnh.",
                    "Luôn mang theo nitroglycerin nếu được kê."
                ],
                preferredMuscles: [.cardio, .fullBody],
                sourceLabel: "AHA/ACC; AACVPR Cardiac Rehab Guideline"
            )

        case .heartFailure:
            return Guidance(
                condition: condition,
                summary: "Tập luyện có kiểm soát cải thiện khả năng gắng sức và chất lượng sống, giảm tái nhập viện.",
                recommended: [
                    "Chỉ tập theo chương trình được bác sĩ tim mạch chỉ định, tốt nhất là có giám sát.",
                    "Aerobic cường độ thấp, ngắt quãng, bắt đầu từ 5-10 phút rồi tăng dần.",
                    "Kháng lực rất nhẹ cho từng nhóm cơ riêng lẻ, tránh bài toàn thân nặng.",
                    "Theo dõi cân nặng hằng ngày — tăng nhanh là dấu hiệu ứ dịch."
                ],
                cautions: [
                    "Ngưng tập nếu tăng trên 2 kg trong 2-3 ngày, phù chân tăng, hoặc khó thở khi nằm.",
                    "Tránh bài gắng sức tối đa và tư thế dốc ngược đầu.",
                    "Không tập khi đang có đợt mất bù."
                ],
                preferredMuscles: [.cardio],
                sourceLabel: "ESC Heart Failure Guideline; AHA"
            )

        case .prediabetes:
            return Guidance(
                condition: condition,
                summary: "Vận động kết hợp giảm 5-7% cân nặng làm giảm nguy cơ tiến triển thành đái tháo đường tới 58% — hơn cả metformin.",
                recommended: [
                    "150 phút/tuần aerobic cường độ vừa, chia đều các ngày.",
                    "Kháng lực 2-3 buổi/tuần để tăng khối cơ — nơi tiêu thụ glucose chính.",
                    "Đi bộ 10-15 phút sau bữa ăn chính.",
                    "Giảm 5-7% cân nặng hiện tại là mục tiêu có bằng chứng mạnh nhất."
                ],
                cautions: [
                    "Không nhịn ăn cực đoan — dễ bỏ cuộc và mất cơ.",
                    "Kiểm tra HbA1c định kỳ để theo dõi hiệu quả."
                ],
                preferredMuscles: [.fullBody, .quads, .back, .cardio],
                sourceLabel: "Diabetes Prevention Program; ADA"
            )

        case .fattyLiver:
            return Guidance(
                condition: condition,
                summary: "Giảm 7-10% cân nặng có thể làm thoái lui viêm gan nhiễm mỡ; vận động giúp giảm mỡ gan ngay cả khi cân chưa đổi.",
                recommended: [
                    "Aerobic 150-240 phút/tuần — tổng khối lượng quan trọng hơn cường độ.",
                    "Kháng lực 2-3 buổi/tuần, có hiệu quả riêng lên mỡ gan.",
                    "Cắt đồ uống có đường và fructose — yếu tố thúc đẩy mạnh nhất.",
                    "Hạn chế rượu bia tối đa."
                ],
                cautions: [
                    "Giảm cân quá nhanh (>1.5 kg/tuần) có thể làm nặng thêm viêm gan.",
                    "Thận trọng với supplement gắn nhãn 'giải độc gan' — nhiều loại gây độc gan thật sự."
                ],
                preferredMuscles: [.cardio, .fullBody],
                sourceLabel: "EASL-EASD-EASO Guideline; AASLD"
            )

        case .gout:
            return Guidance(
                condition: condition,
                summary: "Vận động đều đặn giúp giảm cân và giảm đề kháng insulin — hai yếu tố làm tăng acid uric.",
                recommended: [
                    "Trong đợt cấp: nghỉ khớp đau, chỉ vận động nhẹ các khớp khác.",
                    "Ngoài đợt cấp: aerobic ít tác động (bơi, đạp xe) và kháng lực vừa phải.",
                    "Uống đủ nước — mất nước làm tăng nguy cơ khởi phát cơn.",
                    "Hạn chế bia, rượu mạnh, nội tạng, hải sản có vỏ và nước ngọt fructose."
                ],
                cautions: [
                    "Tập nặng tới kiệt sức làm tăng acid uric tạm thời, dễ kích hoạt cơn gout.",
                    "Giảm cân đột ngột hoặc nhịn ăn kéo dài cũng làm tăng acid uric.",
                    "Không tập cường độ cao trên khớp đang viêm."
                ],
                preferredMuscles: [.cardio, .fullBody],
                sourceLabel: "ACR Gout Guideline; EULAR"
            )

        case .copd:
            return Guidance(
                condition: condition,
                summary: "Phục hồi chức năng hô hấp là can thiệp hiệu quả nhất cho khó thở và khả năng gắng sức ở COPD.",
                recommended: [
                    "Đi bộ hoặc đạp xe ngắt quãng: tập 1-2 phút, nghỉ 1 phút, lặp lại.",
                    "Tập thở chúm môi để kiểm soát khó thở khi gắng sức.",
                    "Kháng lực cho chi dưới — cơ đùi yếu là nguyên nhân chính hạn chế đi lại.",
                    "Dùng thang khó thở Borg thay vì nhịp tim để điều chỉnh cường độ."
                ],
                cautions: [
                    "Dùng thuốc giãn phế quản trước tập nếu được kê.",
                    "Theo dõi SpO2 nếu có máy; dưới 88% thì dừng và nghỉ.",
                    "Tránh tập khi không khí ô nhiễm hoặc quá lạnh.",
                    "Hoãn buổi tập khi đang có đợt cấp."
                ],
                preferredMuscles: [.quads, .cardio, .core],
                sourceLabel: "GOLD Report; ATS/ERS Pulmonary Rehab"
            )

        case .sleepApnea:
            return Guidance(
                condition: condition,
                summary: "Giảm 10% cân nặng có thể giảm khoảng 26% chỉ số ngưng thở; vận động cải thiện cả khi cân chưa đổi.",
                recommended: [
                    "Aerobic 150 phút/tuần kết hợp kháng lực 2-3 buổi.",
                    "Ưu tiên tập buổi sáng hoặc chiều để không quấy giấc ngủ.",
                    "Tập thở và cơ vùng hầu họng (myofunctional therapy) có bằng chứng hỗ trợ.",
                    "Dùng CPAP đều đặn nếu đã được chỉ định — tập không thay thế được."
                ],
                cautions: [
                    "Buồn ngủ ban ngày nặng làm tăng nguy cơ chấn thương khi tập; ngủ đủ trước buổi nặng.",
                    "Tránh rượu và thuốc an thần buổi tối vì làm nặng thêm ngưng thở."
                ],
                preferredMuscles: [.cardio, .fullBody],
                sourceLabel: "AASM; ATS Clinical Practice Guideline"
            )

        case .osteoporosis:
            return Guidance(
                condition: condition,
                summary: "Tải trọng lên xương là kích thích duy nhất giúp tăng mật độ xương — thuốc giữ xương, còn tập mới tạo xương.",
                recommended: [
                    "Kháng lực tải cao có giám sát (nghiên cứu LIFTMOR) cho hiệu quả tốt nhất trên mật độ xương.",
                    "Bài chịu tải trọng: đi bộ nhanh, bước lên bục, nhảy nhẹ nếu dung nạp được.",
                    "Tập thăng bằng để giảm nguy cơ té ngã — gãy xương chủ yếu do ngã.",
                    "Đảm bảo đủ canxi 1000-1200 mg và vitamin D mỗi ngày."
                ],
                cautions: [
                    "Tránh gập cột sống có tải (sit-up, cúi nhấc vật nặng) — nguy cơ xẹp đốt sống.",
                    "Tránh xoay vặn cột sống mạnh và các bài có nguy cơ ngã cao.",
                    "Bắt đầu dưới hướng dẫn của kỹ thuật viên vật lý trị liệu nếu T-score rất thấp."
                ],
                preferredMuscles: [.back, .glutes, .quads, .core],
                sourceLabel: "Royal Osteoporosis Society; LIFTMOR trial"
            )

        case .rheumatoidArthritis:
            return Guidance(
                condition: condition,
                summary: "Vận động không làm bệnh nặng thêm — ngược lại giúp giảm đau, giữ chức năng khớp và chống teo cơ.",
                recommended: [
                    "Vận động khớp hết tầm mỗi ngày, kể cả ngày đau.",
                    "Kháng lực vừa phải 2-3 buổi/tuần; bắt đầu từ tự trọng và dây kháng lực.",
                    "Aerobic ít tác động: bơi, đạp xe, tập dưới nước.",
                    "Tập vào lúc thuốc phát huy tác dụng tốt nhất trong ngày."
                ],
                cautions: [
                    "Đợt bùng phát: giảm còn vận động nhẹ hết tầm, không tập kháng lực.",
                    "Tránh nắm chặt kéo dài và tải mạnh lên khớp bàn tay nhỏ.",
                    "Đau tăng kéo dài trên 2 giờ sau tập là dấu hiệu quá tải."
                ],
                preferredMuscles: [.fullBody, .core, .quads],
                sourceLabel: "EULAR Recommendations; ACR"
            )

        case .shoulderImpingement:
            return Guidance(
                condition: condition,
                summary: "Tập phục hồi có tiến triển hiệu quả tương đương phẫu thuật nội soi giải ép trong phần lớn trường hợp.",
                recommended: [
                    "Mạnh nhóm xoay ngoài và cơ chóp xoay: external rotation với dây kháng lực.",
                    "Mạnh cơ ổn định xương bả vai: serratus punch, wall slide, prone Y-T-W.",
                    "Tập trong tầm không đau, tăng tải từ từ theo tuần.",
                    "Kéo giãn ngực nhỏ và cơ ngực lớn nếu vai đổ trước."
                ],
                cautions: [
                    "Tránh đẩy vai qua đầu, upright row, và kéo xà sau gáy khi đang đau.",
                    "Hạn chế bench press biên độ sâu và dip trong giai đoạn cấp.",
                    "Đau về đêm dai dẳng cần đi khám để loại trừ rách chóp xoay."
                ],
                preferredMuscles: [.shoulders, .back],
                sourceLabel: "BJSM; JOSPT Clinical Practice Guideline"
            )

        case .plantarFasciitis:
            return Guidance(
                condition: condition,
                summary: "Tập kháng lực bắp chân và gan chân tải cao cho kết quả tốt hơn chỉ kéo giãn đơn thuần.",
                recommended: [
                    "Calf raise tải cao, biên độ chậm, có kê khăn dưới các ngón chân.",
                    "Kéo giãn cân gan chân buổi sáng trước khi bước xuống giường.",
                    "Lăn bóng hoặc chai nước lạnh dưới gan chân.",
                    "Mạnh cơ mông nhỡ để cải thiện trục chi dưới."
                ],
                cautions: [
                    "Giảm chạy bộ và nhảy trong giai đoạn đau; chuyển sang đạp xe hoặc bơi.",
                    "Tránh đi chân đất trên nền cứng.",
                    "Đổi giày nếu đế đã mòn hoặc quá mềm."
                ],
                preferredMuscles: [.calves, .glutes],
                sourceLabel: "JOSPT; Rathleff et al. 2015"
            )

        case .scoliosis:
            return Guidance(
                condition: condition,
                summary: "Bài tập chuyên biệt theo trường phái Schroth giúp cải thiện tư thế và giảm đau, đặc biệt ở đường cong nhẹ đến vừa.",
                recommended: [
                    "Bài tập chỉnh tư thế ba chiều (Schroth) dưới hướng dẫn chuyên viên.",
                    "Mạnh core đều hai bên và cơ dựng sống.",
                    "Bơi và các môn đối xứng giúp giữ linh hoạt cột sống.",
                    "Tập thở giãn nở phía lõm của đường cong."
                ],
                cautions: [
                    "Tránh tải nặng bất đối xứng (xách một bên, bài một tay tải lớn) khi chưa đủ khoẻ core.",
                    "Đường cong tiến triển nhanh cần theo dõi bởi bác sĩ cột sống.",
                    "Không tự ý tập các bài kéo giãn mạnh một bên."
                ],
                preferredMuscles: [.core, .back, .glutes],
                sourceLabel: "SOSORT Guidelines"
            )

        case .hyperthyroidism:
            return Guidance(
                condition: condition,
                summary: "Chuyển hoá tăng cao nên dễ sụt cân và mất cơ; tập cần nhẹ nhàng cho tới khi hormone về bình thường.",
                recommended: [
                    "Chờ bệnh được kiểm soát rồi mới tăng cường độ.",
                    "Kháng lực nhẹ để chống mất cơ, nghỉ dài giữa set.",
                    "Ăn đủ calo và đạm vì nhu cầu tăng rõ."
                ],
                cautions: [
                    "Tim đập nhanh, run tay, không chịu được nóng — ngưng tập và đi khám.",
                    "Tránh aerobic cường độ cao khi chưa kiểm soát được bệnh.",
                    "Chú ý thải nhiệt vì cơ thể vốn đã sinh nhiệt nhiều."
                ],
                preferredMuscles: [.fullBody],
                sourceLabel: "ATA Hyperthyroidism Guideline"
            )

        case .chronicKidneyDisease:
            return Guidance(
                condition: condition,
                summary: "Vận động cải thiện thể lực, huyết áp và chất lượng sống ở mọi giai đoạn bệnh thận mạn.",
                recommended: [
                    "Aerobic cường độ vừa 3-5 buổi/tuần, bắt đầu rất ngắn rồi tăng dần.",
                    "Kháng lực 2-3 buổi/tuần để chống teo cơ — rất phổ biến ở bệnh thận mạn.",
                    "Người chạy thận có thể tập nhẹ ngay trong buổi lọc nếu được cho phép."
                ],
                cautions: [
                    "Lượng đạm và nước phải theo chỉ định của bác sĩ thận, không tự tăng đạm theo mục tiêu thể hình.",
                    "Tránh NSAID giảm đau sau tập — độc với thận.",
                    "Thận trọng với creatine và các supplement đạm liều cao."
                ],
                preferredMuscles: [.fullBody, .cardio],
                sourceLabel: "KDIGO; KDOQI"
            )

        case .irritableBowel:
            return Guidance(
                condition: condition,
                summary: "Vận động cường độ vừa làm giảm triệu chứng và cải thiện nhu động ruột.",
                recommended: [
                    "Đi bộ, yoga, đạp xe nhẹ 20-30 phút hầu hết các ngày.",
                    "Tập thở và thư giãn — trục não-ruột ảnh hưởng mạnh tới triệu chứng.",
                    "Ăn cách buổi tập ít nhất 2 giờ."
                ],
                cautions: [
                    "Chạy đường dài và tập cường độ rất cao có thể gây đau bụng, tiêu chảy khi gắng sức.",
                    "Thận trọng với đồ uống thể thao nhiều fructose và đường cồn (sorbitol, xylitol).",
                    "Bổ sung xơ nên tăng từ từ để tránh đầy hơi."
                ],
                preferredMuscles: [.core, .cardio],
                sourceLabel: "ACG IBS Guideline; BDA"
            )

        case .varicoseVeins:
            return Guidance(
                condition: condition,
                summary: "Bơm cơ bắp chân là cơ chế đẩy máu tĩnh mạch về tim — cơ bắp chân khoẻ giúp giảm ứ trệ.",
                recommended: [
                    "Calf raise và đi bộ đều đặn để kích hoạt bơm cơ bắp chân.",
                    "Đạp xe và bơi — tư thế không dồn áp lực lên tĩnh mạch chân.",
                    "Gác chân cao 15-20 phút sau buổi tập.",
                    "Dùng vớ áp lực nếu bác sĩ chỉ định."
                ],
                cautions: [
                    "Tránh đứng yên tại chỗ quá lâu và squat nặng nín thở.",
                    "Hạn chế xông hơi, tắm nước rất nóng ngay sau tập.",
                    "Chân sưng đau đột ngột một bên cần đi khám ngay để loại trừ huyết khối."
                ],
                preferredMuscles: [.calves, .cardio],
                sourceLabel: "SVS/AVF Guidelines"
            )

        case .migraine:
            return Guidance(
                condition: condition,
                summary: "Aerobic đều đặn giảm tần suất cơn đau nửa đầu, hiệu quả tương đương một số thuốc dự phòng.",
                recommended: [
                    "Aerobic cường độ vừa 40 phút, 3 buổi/tuần (theo thử nghiệm của Varkey 2011).",
                    "Khởi động dài để tránh cơn khởi phát do gắng sức đột ngột.",
                    "Giữ lịch ngủ và giờ ăn đều đặn — thay đổi thất thường là yếu tố kích hoạt mạnh.",
                    "Uống đủ nước trước và trong buổi tập."
                ],
                cautions: [
                    "Gắng sức đột ngột cường độ cao có thể kích hoạt cơn.",
                    "Tránh tập dưới nắng gắt và nơi ánh sáng nhấp nháy mạnh.",
                    "Không tập khi đang trong cơn đau cấp."
                ],
                preferredMuscles: [.cardio, .core],
                sourceLabel: "Varkey et al. 2011; American Headache Society"
            )

        case .depressionAnxiety:
            return Guidance(
                condition: condition,
                summary: "Vận động có hiệu quả rõ rệt lên triệu chứng trầm cảm và lo âu, so sánh được với liệu pháp tâm lý ở mức nhẹ đến vừa.",
                recommended: [
                    "Bất kỳ vận động nào cũng tốt hơn không vận động — bắt đầu từ 10 phút đi bộ.",
                    "Aerobic 3-5 buổi/tuần, 30-45 phút, duy trì ít nhất 8-12 tuần mới thấy rõ.",
                    "Kháng lực cũng có bằng chứng tốt, đặc biệt với lo âu.",
                    "Tập ngoài trời hoặc theo nhóm cộng thêm lợi ích."
                ],
                cautions: [
                    "Đặt mục tiêu nhỏ và dễ đạt — kỳ vọng quá cao dễ thành gánh nặng.",
                    "Tập không thay thế điều trị; giữ liên lạc với bác sĩ nếu đang dùng thuốc.",
                    "Có ý nghĩ tự làm hại bản thân cần tìm hỗ trợ chuyên môn ngay."
                ],
                preferredMuscles: [.cardio, .fullBody],
                sourceLabel: "BJSM 2023 umbrella review; WHO"
            )

        case .insomnia:
            return Guidance(
                condition: condition,
                summary: "Tập đều đặn cải thiện chất lượng giấc ngủ, nhưng thời điểm tập rất quan trọng.",
                recommended: [
                    "Tập buổi sáng hoặc chiều; ánh sáng ban ngày giúp chỉnh nhịp sinh học.",
                    "Aerobic cường độ vừa 30 phút hầu hết các ngày.",
                    "Giãn cơ nhẹ hoặc yoga buổi tối."
                ],
                cautions: [
                    "Tránh tập cường độ cao trong vòng 2-3 giờ trước giờ ngủ.",
                    "Hạn chế caffeine và pre-workout sau 14h.",
                    "Thiếu ngủ kéo dài làm giảm phục hồi — giảm khối lượng tập thay vì cố ép."
                ],
                preferredMuscles: [.cardio, .core],
                sourceLabel: "AASM; ACSM"
            )
        }
    }

    static func allGuidance(for conditions: [HealthConditionKind]) -> [Guidance] {
        conditions.compactMap(guidance(for:))
    }

    /// Nhóm cơ nên ưu tiên dựa trên toàn bộ bệnh nền của người dùng.
    static func priorityMuscles(for conditions: [HealthConditionKind]) -> [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var result: [MuscleGroup] = []
        for g in allGuidance(for: conditions) {
            for m in g.preferredMuscles where !seen.contains(m) {
                seen.insert(m)
                result.append(m)
            }
        }
        return result
    }
}
