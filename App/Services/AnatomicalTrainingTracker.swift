import Foundation

/// Exercise-to-muscle links are conservative biomechanical estimates, not EMG measurements.
/// Unknown slugs and broad workout-group tags never expand to all constituent muscles.
enum AnatomicalTrainingTracker {
    struct Targets {
        var direct: Set<AnatomicalMuscle> = []
        var assisting: Set<AnatomicalMuscle> = []
    }
    struct Activity {
        var targets: Targets
        var sets: Int
    }
    struct Record {
        var date: Date
        var completed: Bool
        var activities: [Activity]
    }
    struct Stat: Identifiable {
        var muscle: AnatomicalMuscle
        var id: String { muscle.rawValue }
        var days = 0
        var sessions = 0
        var directSets = 0
        var assistingSets = 0
        var lastTrained: Date?
        var trained: Bool { sessions > 0 }
    }
    static func stats(records: [Record], now: Date = .now, calendar: Calendar = WeeklyMuscleTracker.calendar()) -> [Stat] {
        let week = WeeklyMuscleTracker.week(containing: now, calendar: calendar)
        let records = records.filter { $0.completed && $0.date >= week.start && $0.date < week.end && $0.date <= now }
        return AnatomicalMuscle.selectableCases.map { muscle in
            var stat = Stat(muscle: muscle)
            var dates = Set<Date>()
            for record in records {
                var used = false
                for activity in record.activities where activity.sets > 0 {
                    if activity.targets.direct.contains(muscle) { stat.directSets += activity.sets; used = true }
                    else if activity.targets.assisting.contains(muscle) { stat.assistingSets += activity.sets; used = true }
                }
                if used {
                    stat.sessions += 1
                    dates.insert(calendar.startOfDay(for: record.date))
                    stat.lastTrained = max(stat.lastTrained ?? record.date, record.date)
                }
            }
            stat.days = dates.count
            return stat
        }
    }

    static func targets(slug: String, isCustom: Bool = false) -> Targets {
        guard !isCustom else { return Targets() }
        return mapping[slug] ?? Targets()
    }
    private static let mapping: [String: Targets] = {
        var map: [String: Targets] = [:]
        func add(_ names: [String], _ direct: Set<AnatomicalMuscle>, _ assisting: Set<AnatomicalMuscle> = []) {
            for name in names { map["seed-" + name] = Targets(direct: direct, assisting: assisting.subtracting(direct)) }
        }
        let quads: Set<AnatomicalMuscle> = [.rectusFemoris, .vastusLateralis, .vastusMedialis, .vastusIntermedius]
        let hamstrings: Set<AnatomicalMuscle> = [.bicepsFemoris, .semitendinosus, .semimembranosus]
        let biceps: Set<AnatomicalMuscle> = [.longHeadBiceps, .shortHeadBiceps]
        let triceps: Set<AnatomicalMuscle> = [.longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps]
        let pressAssist = triceps.union([.anteriorDeltoid])
        add(["barbell-back-squat", "barbell-front-squat", "box-squat", "pause-squat", "hack-squat", "goblet-squat", "leg-press", "bulgarian-split-squat", "walking-lunge", "reverse-lunge", "step-up", "pistol-squat", "belt-squat"], [.vastusLateralis, .vastusMedialis, .vastusIntermedius, .gluteusMaximus], [.rectusFemoris])
        add(["leg-extension", "sissy-squat", "wall-sit"], quads)
        add(["lying-leg-curl", "seated-leg-curl", "nordic-hamstring-curl", "glute-ham-raise"], hamstrings)
        add(["romanian-deadlift", "stiff-leg-deadlift", "single-leg-romanian-deadlift", "good-morning"], hamstrings.union([.gluteusMaximus]), [.erectorSpinae])
        add(["conventional-deadlift", "rack-pull"], [.gluteusMaximus, .erectorSpinae], hamstrings)
        add(["sumo-deadlift", "sumo-squat"], [.gluteusMaximus, .adductorMagnus, .vastusLateralis, .vastusMedialis, .vastusIntermedius])
        add(["hip-thrust", "glute-bridge", "single-leg-hip-thrust", "cable-kickback"], [.gluteusMaximus])
        add(["hip-abduction-machine", "banded-lateral-walk"], [.gluteusMedius, .gluteusMinimus], [.tensorFasciaeLatae])
        add(["standing-calf-raise", "donkey-calf-raise", "single-leg-calf-raise"], [.gastrocnemius, .soleus])
        add(["seated-calf-raise"], [.soleus])
        add(["barbell-bench-press", "dumbbell-bench-press", "push-up", "machine-chest-press"], [.middlePectoralisMajor], pressAssist.union([.upperPectoralisMajor, .lowerPectoralisMajor]))
        add(["incline-barbell-press", "incline-dumbbell-press"], [.upperPectoralisMajor], pressAssist.union([.middlePectoralisMajor]))
        add(["decline-barbell-press", "chest-dip"], [.lowerPectoralisMajor], pressAssist.union([.middlePectoralisMajor]))
        add(["incline-push-up"], [.middlePectoralisMajor], pressAssist.union([.lowerPectoralisMajor]))
        add(["dumbbell-fly", "cable-crossover", "pec-deck", "svend-press"], [.middlePectoralisMajor], [.upperPectoralisMajor, .lowerPectoralisMajor])
        add(["incline-dumbbell-fly"], [.upperPectoralisMajor], [.middlePectoralisMajor])
        add(["pull-up", "chin-up", "wide-grip-pull-up", "lat-pulldown", "close-grip-lat-pulldown"], [.latissimusDorsi], biceps.union([.brachialis, .teresMajor]))
        add(["straight-arm-pulldown"], [.latissimusDorsi], [.teresMajor])
        add(["barbell-bent-over-row", "pendlay-row", "t-bar-row", "seated-cable-row", "single-arm-dumbbell-row", "chest-supported-row", "inverted-row"], [.latissimusDorsi, .rhomboidMajor, .rhomboidMinor, .middleTrapezius], biceps.union([.lowerTrapezius, .posteriorDeltoid]))
        add(["back-extension"], [.erectorSpinae], [.gluteusMaximus])
        add(["shrug"], [.upperTrapezius])
        add(["overhead-press", "push-press", "seated-dumbbell-shoulder-press", "arnold-press", "landmine-press"], [.anteriorDeltoid], triceps.union([.middleDeltoid, .upperTrapezius, .lowerTrapezius]))
        add(["lateral-raise", "cable-lateral-raise"], [.middleDeltoid])
        add(["front-raise"], [.anteriorDeltoid])
        add(["rear-delt-fly", "face-pull"], [.posteriorDeltoid], [.rhomboidMajor, .middleTrapezius, .lowerTrapezius])
        add(["barbell-curl", "ez-bar-curl", "incline-dumbbell-curl", "preacher-curl", "cable-curl", "concentration-curl", "spider-curl"], biceps, [.brachialis])
        add(["dumbbell-hammer-curl"], [.brachialis, .brachioradialis], biceps)
        add(["triceps-pushdown", "rope-pushdown", "skull-crusher", "kickback"], triceps)
        add(["overhead-triceps-extension"], [.longHeadTriceps], [.lateralHeadTriceps, .medialHeadTriceps])
        add(["triceps-dip", "bench-dip", "close-grip-bench-press", "diamond-push-up"], triceps, [.middlePectoralisMajor, .anteriorDeltoid])
        add(["wrist-curl"], [.flexorCarpiRadialis, .flexorCarpiUlnaris])
        add(["reverse-wrist-curl"], [.extensorCarpiRadialisLongus, .extensorCarpiUlnaris])
        add(["cable-crunch", "reverse-crunch", "ab-wheel-rollout", "hollow-body-hold", "plank"], [.rectusAbdominis])
        add(["side-plank", "cable-woodchop", "russian-twist", "pallof-press"], [.externalOblique, .internalOblique])
        add(["hanging-leg-raise", "hanging-knee-raise", "v-up"], [.iliopsoas], [.rectusAbdominis])
        return map
    }()
}
