import Foundation

/// Named structures for a selective musculoskeletal atlas, independent of the older workout groups.
/// Stable raw values are also the keys of per-structure notes.
enum AnatomicalMuscle: String, CaseIterable, Identifiable, Codable {
    case sternocleidomastoid, spleniusCapitis, trapezius, upperTrapezius, middleTrapezius, lowerTrapezius, levatorScapulae
    case pectoralisMajor, upperPectoralisMajor, middlePectoralisMajor, lowerPectoralisMajor, pectoralisMinor, subclavius, serratusAnterior
    case externalIntercostals, internalIntercostals
    case anteriorDeltoid, middleDeltoid, posteriorDeltoid
    case supraspinatus, infraspinatus, teresMinor, subscapularis, teresMajor
    case rhomboidMajor, rhomboidMinor, latissimusDorsi, erectorSpinae, multifidus, quadratusLumborum
    case rectusAbdominis, externalOblique, internalOblique, transversusAbdominis
    case bicepsBrachii, longHeadBiceps, shortHeadBiceps, brachialis, coracobrachialis
    case tricepsBrachii, longHeadTriceps, lateralHeadTriceps, medialHeadTriceps, brachioradialis
    case flexorCarpiRadialis, flexorCarpiUlnaris, palmarisLongus, flexorDigitorumSuperficialis
    case extensorDigitorum, extensorCarpiRadialisLongus, extensorCarpiUlnaris
    case gluteusMaximus, gluteusMedius, gluteusMinimus, iliopsoas, piriformis
    case tensorFasciaeLatae, sartorius, adductorLongus, adductorBrevis, adductorMagnus, gracilis
    case rectusFemoris, vastusLateralis, vastusMedialis, vastusIntermedius
    case bicepsFemoris, semitendinosus, semimembranosus
    case gastrocnemius, soleus, tibialisAnterior, fibularisLongus, extensorDigitorumLongus
    case popliteus, tibialisPosterior, flexorDigitorumLongus, flexorHallucisLongus

    var id: String { rawValue }
    var info: Info { Self.catalogue[self]! }
    var label: String { info.label }
    var latin: String { info.latin }
    var group: MuscleGroup? { info.group }
    var noteKey: String { "anatomy.\(rawValue)" }
    /// Old aggregate identifiers remain decodable for saved workouts and notes, but are not selectable regions.
    static var selectableCases: [Self] { allCases.filter { !$0.isLegacyAggregate } }
    var isLegacyAggregate: Bool { [.pectoralisMajor, .trapezius, .bicepsBrachii, .tricepsBrachii].contains(self) }
    var parentMuscle: Self? {
        switch self {
        case .upperPectoralisMajor, .middlePectoralisMajor, .lowerPectoralisMajor: return .pectoralisMajor
        case .upperTrapezius, .middleTrapezius, .lowerTrapezius: return .trapezius
        case .longHeadBiceps, .shortHeadBiceps: return .bicepsBrachii
        case .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps: return .tricepsBrachii
        default: return nil
        }
    }

    struct Info {
        var label: String
        var latin: String
        var region: String
        var group: MuscleGroup?
        var source: AnatomySource
        var deep: Bool
    }

    enum AnatomySource: String, CaseIterable, Identifiable {
        case neck, trunk, upperLimb, lowerLimb
        var id: String { rawValue }
        var chapter: String {
            switch self {
            case .neck: return "11.3 · Đầu, cổ và lưng"
            case .trunk: return "11.4 · Thành bụng và ngực"
            case .upperLimb: return "11.5 · Đai vai và chi trên"
            case .lowerLimb: return "11.6 · Đai chậu và chi dưới"
            }
        }
        var url: URL {
            let suffix: String
            switch self {
            case .neck: suffix = "11-3-axial-muscles-of-the-head-neck-and-back"
            case .trunk: suffix = "11-4-axial-muscles-of-the-abdominal-wall-and-thorax"
            case .upperLimb: suffix = "11-5-muscles-of-the-pectoral-girdle-and-upper-limbs"
            case .lowerLimb: suffix = "11-6-appendicular-muscles-of-the-pelvic-girdle-and-lower-limbs"
            }
            return URL(string: "https://openstax.org/books/anatomy-and-physiology-2e/pages/" + suffix)!
        }
    }

    private static let catalogue: [Self: Info] = {
        var entries: [Self: Info] = [:]
        func add(_ id: Self, _ vi: String, _ latin: String, _ region: String, _ group: MuscleGroup?, _ source: AnatomySource, deep: Bool = false) {
            entries[id] = Info(label: vi, latin: latin, region: region, group: group, source: source, deep: deep)
        }
        add(.sternocleidomastoid, "Ức–đòn–chũm", "Sternocleidomastoid", "Cổ", nil, .neck)
        add(.spleniusCapitis, "Gối đầu", "Splenius capitis", "Cổ", nil, .neck, deep: true)
        add(.trapezius, "Thang", "Trapezius", "Lưng", .back, .upperLimb)
        add(.upperTrapezius, "Thang · bó trên", "Trapezius — upper fibers", "Lưng trên", .back, .upperLimb)
        add(.middleTrapezius, "Thang · bó giữa", "Trapezius — middle fibers", "Lưng trên", .back, .upperLimb)
        add(.lowerTrapezius, "Thang · bó dưới", "Trapezius — lower fibers", "Lưng trên", .back, .upperLimb)
        add(.levatorScapulae, "Nâng vai", "Levator scapulae", "Cổ", .back, .upperLimb, deep: true)
        add(.pectoralisMajor, "Ngực lớn", "Pectoralis major", "Ngực", .chest, .upperLimb)
        add(.upperPectoralisMajor, "Ngực lớn · vùng trên", "Pectoralis major — clavicular region", "Ngực", .chest, .upperLimb)
        add(.middlePectoralisMajor, "Ngực lớn · vùng giữa", "Pectoralis major — sternocostal region", "Ngực", .chest, .upperLimb)
        add(.lowerPectoralisMajor, "Ngực lớn · vùng dưới", "Pectoralis major — lower costal region", "Ngực", .chest, .upperLimb)
        add(.pectoralisMinor, "Ngực bé", "Pectoralis minor", "Ngực", .chest, .upperLimb, deep: true)
        add(.subclavius, "Dưới đòn", "Subclavius", "Ngực", nil, .upperLimb, deep: true)
        add(.serratusAnterior, "Răng trước", "Serratus anterior", "Ngực", nil, .upperLimb)
        add(.externalIntercostals, "Liên sườn ngoài", "External intercostals", "Ngực", nil, .trunk, deep: true)
        add(.internalIntercostals, "Liên sườn trong", "Internal intercostals", "Ngực", nil, .trunk, deep: true)
        add(.anteriorDeltoid, "Delta · bó trước", "Deltoid — anterior", "Vai", .shoulders, .upperLimb)
        add(.middleDeltoid, "Delta · bó giữa", "Deltoid — middle", "Vai", .shoulders, .upperLimb)
        add(.posteriorDeltoid, "Delta · bó sau", "Deltoid — posterior", "Vai", .shoulders, .upperLimb)
        add(.supraspinatus, "Trên gai", "Supraspinatus", "Chóp xoay", .shoulders, .upperLimb, deep: true)
        add(.infraspinatus, "Dưới gai", "Infraspinatus", "Chóp xoay", .shoulders, .upperLimb, deep: true)
        add(.teresMinor, "Tròn bé", "Teres minor", "Chóp xoay", .shoulders, .upperLimb, deep: true)
        add(.subscapularis, "Dưới vai", "Subscapularis", "Chóp xoay", .shoulders, .upperLimb, deep: true)
        add(.teresMajor, "Tròn lớn", "Teres major", "Lưng", .back, .upperLimb)
        add(.rhomboidMajor, "Trám lớn", "Rhomboid major", "Lưng", .back, .upperLimb, deep: true)
        add(.rhomboidMinor, "Trám bé", "Rhomboid minor", "Lưng", .back, .upperLimb, deep: true)
        add(.latissimusDorsi, "Lưng rộng (xô)", "Latissimus dorsi", "Lưng", .back, .upperLimb)
        add(.erectorSpinae, "Nhóm dựng sống", "Erector spinae", "Lưng", .back, .neck, deep: true)
        add(.multifidus, "Đa liên", "Multifidus", "Lưng", .back, .neck, deep: true)
        add(.quadratusLumborum, "Vuông thắt lưng", "Quadratus lumborum", "Lưng", .back, .neck, deep: true)
        add(.rectusAbdominis, "Thẳng bụng", "Rectus abdominis", "Bụng", .core, .trunk)
        add(.externalOblique, "Chéo bụng ngoài", "External oblique", "Bụng", .core, .trunk)
        add(.internalOblique, "Chéo bụng trong", "Internal oblique", "Bụng", .core, .trunk, deep: true)
        add(.transversusAbdominis, "Ngang bụng", "Transversus abdominis", "Bụng", .core, .trunk, deep: true)
        add(.bicepsBrachii, "Nhị đầu cánh tay", "Biceps brachii", "Cánh tay", .biceps, .upperLimb)
        add(.longHeadBiceps, "Nhị đầu · đầu dài", "Biceps brachii — long head", "Cánh tay", .biceps, .upperLimb)
        add(.shortHeadBiceps, "Nhị đầu · đầu ngắn", "Biceps brachii — short head", "Cánh tay", .biceps, .upperLimb)
        add(.brachialis, "Cánh tay", "Brachialis", "Cánh tay", .biceps, .upperLimb, deep: true)
        add(.coracobrachialis, "Quạ–cánh tay", "Coracobrachialis", "Cánh tay", nil, .upperLimb, deep: true)
        add(.tricepsBrachii, "Tam đầu cánh tay", "Triceps brachii", "Cánh tay", .triceps, .upperLimb)
        add(.longHeadTriceps, "Tam đầu · đầu dài", "Triceps brachii — long head", "Cánh tay", .triceps, .upperLimb)
        add(.lateralHeadTriceps, "Tam đầu · đầu ngoài", "Triceps brachii — lateral head", "Cánh tay", .triceps, .upperLimb)
        add(.medialHeadTriceps, "Tam đầu · đầu trong", "Triceps brachii — medial head", "Cánh tay", .triceps, .upperLimb)
        add(.brachioradialis, "Cánh tay quay", "Brachioradialis", "Cẳng tay", .forearms, .upperLimb)
        add(.flexorCarpiRadialis, "Gấp cổ tay quay", "Flexor carpi radialis", "Cẳng tay", .forearms, .upperLimb)
        add(.flexorCarpiUlnaris, "Gấp cổ tay trụ", "Flexor carpi ulnaris", "Cẳng tay", .forearms, .upperLimb)
        add(.palmarisLongus, "Gan tay dài", "Palmaris longus", "Cẳng tay", .forearms, .upperLimb)
        add(.flexorDigitorumSuperficialis, "Gấp các ngón nông", "Flexor digitorum superficialis", "Cẳng tay", .forearms, .upperLimb, deep: true)
        add(.extensorDigitorum, "Duỗi các ngón tay", "Extensor digitorum", "Cẳng tay", .forearms, .upperLimb)
        add(.extensorCarpiRadialisLongus, "Duỗi cổ tay quay dài", "Extensor carpi radialis longus", "Cẳng tay", .forearms, .upperLimb)
        add(.extensorCarpiUlnaris, "Duỗi cổ tay trụ", "Extensor carpi ulnaris", "Cẳng tay", .forearms, .upperLimb)
        add(.gluteusMaximus, "Mông lớn", "Gluteus maximus", "Hông", .glutes, .lowerLimb)
        add(.gluteusMedius, "Mông nhỡ", "Gluteus medius", "Hông", .glutes, .lowerLimb)
        add(.gluteusMinimus, "Mông bé", "Gluteus minimus", "Hông", .glutes, .lowerLimb, deep: true)
        add(.iliopsoas, "Nhóm thắt lưng–chậu", "Iliopsoas", "Hông", nil, .lowerLimb, deep: true)
        add(.piriformis, "Hình lê", "Piriformis", "Hông", nil, .lowerLimb, deep: true)
        add(.tensorFasciaeLatae, "Căng mạc đùi", "Tensor fasciae latae", "Hông", nil, .lowerLimb)
        add(.sartorius, "May", "Sartorius", "Đùi", nil, .lowerLimb)
        add(.adductorLongus, "Khép dài", "Adductor longus", "Đùi", nil, .lowerLimb)
        add(.adductorBrevis, "Khép ngắn", "Adductor brevis", "Đùi", nil, .lowerLimb, deep: true)
        add(.adductorMagnus, "Khép lớn", "Adductor magnus", "Đùi", nil, .lowerLimb, deep: true)
        add(.gracilis, "Thon", "Gracilis", "Đùi", nil, .lowerLimb)
        add(.rectusFemoris, "Thẳng đùi", "Rectus femoris", "Đùi", .quads, .lowerLimb)
        add(.vastusLateralis, "Rộng ngoài", "Vastus lateralis", "Đùi", .quads, .lowerLimb)
        add(.vastusMedialis, "Rộng trong", "Vastus medialis", "Đùi", .quads, .lowerLimb)
        add(.vastusIntermedius, "Rộng giữa", "Vastus intermedius", "Đùi", .quads, .lowerLimb, deep: true)
        add(.bicepsFemoris, "Nhị đầu đùi", "Biceps femoris", "Đùi", .hamstrings, .lowerLimb)
        add(.semitendinosus, "Bán gân", "Semitendinosus", "Đùi", .hamstrings, .lowerLimb)
        add(.semimembranosus, "Bán màng", "Semimembranosus", "Đùi", .hamstrings, .lowerLimb, deep: true)
        add(.gastrocnemius, "Bụng chân", "Gastrocnemius", "Cẳng chân", .calves, .lowerLimb)
        add(.soleus, "Dép", "Soleus", "Cẳng chân", .calves, .lowerLimb, deep: true)
        add(.tibialisAnterior, "Chày trước", "Tibialis anterior", "Cẳng chân", nil, .lowerLimb)
        add(.fibularisLongus, "Mác dài", "Fibularis longus", "Cẳng chân", nil, .lowerLimb)
        add(.extensorDigitorumLongus, "Duỗi dài các ngón chân", "Extensor digitorum longus", "Cẳng chân", nil, .lowerLimb)
        add(.popliteus, "Khoeo", "Popliteus", "Cẳng chân", nil, .lowerLimb, deep: true)
        add(.tibialisPosterior, "Chày sau", "Tibialis posterior", "Cẳng chân", nil, .lowerLimb, deep: true)
        add(.flexorDigitorumLongus, "Gấp dài các ngón chân", "Flexor digitorum longus", "Cẳng chân", nil, .lowerLimb, deep: true)
        add(.flexorHallucisLongus, "Gấp dài ngón cái chân", "Flexor hallucis longus", "Cẳng chân", nil, .lowerLimb, deep: true)
        return entries
    }()
}
