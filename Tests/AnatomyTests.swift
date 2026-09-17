import Foundation

@main
struct AnatomyTests {
    static func main() {
        let catalogue = Set(AnatomicalMuscle.allCases)
        var drawn = Set<AnatomicalMuscle>()
        for layer in AnatomyLayer.allCases {
            for rear in [false, true] {
                for region in MuscleAnatomyGeometry.regions(rear: rear, layer: layer) {
                    drawn.insert(region.muscle)
                    let tokens = region.path.split(separator: " ")
                    var i = 0
                    while i < tokens.count {
                        let command = tokens[i]; i += 1
                        let count: Int
                        switch command { case "M", "L": count = 2; case "Q": count = 4; case "Z": count = 0; default: fatalError("Invalid path command") }
                        for _ in 0..<count { assert(i < tokens.count && Double(tokens[i]) != nil); i += 1 }
                    }
                }
            }
        }
        assert(drawn == catalogue, "Every named structure needs a tappable region")
        for muscle in catalogue {
            assert(!muscle.label.isEmpty && !muscle.latin.isEmpty)
            assert(muscle.info.source.url.host == "openstax.org")
            let location = MuscleAnatomyGeometry.location(of: muscle)
            assert(MuscleAnatomyGeometry.regions(rear: location.rear, layer: location.layer).contains { $0.muscle == muscle })
        }
        let shoulder = AnatomicalTrainingTracker.targets(slug: "seed-lateral-raise")
        assert(shoulder.direct == [.middleDeltoid] && !shoulder.direct.contains(.subscapularis))
        assert(AnatomicalTrainingTracker.targets(slug: "custom-lateral-raise").direct.isEmpty)
        assert(AnatomicalTrainingTracker.targets(slug: "seed-lateral-raise", isCustom: true).direct.isEmpty)
        assert(AnatomicalTrainingTracker.targets(slug: "wger-123").direct.isEmpty)
        let calf = AnatomicalTrainingTracker.targets(slug: "seed-standing-calf-raise")
        assert(!calf.direct.contains(.tibialisAnterior))
        let now = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z")!
        let activity = AnatomicalTrainingTracker.Activity(targets: shoulder, sets: 3)
        let records = [AnatomicalTrainingTracker.Record(date: now, completed: true, activities: [activity, activity])]
        let stats = AnatomicalTrainingTracker.stats(records: records, now: now)
        let trained = stats.filter(\.trained)
        assert(trained.count == 1 && trained[0].sessions == 1 && trained[0].days == 1 && trained[0].directSets == 6)
        let monday = WeeklyMuscleTracker.week(containing: now).end
        assert(AnatomicalTrainingTracker.stats(records: records, now: monday).allSatisfy { !$0.trained })
        print("PASS: \(catalogue.count) named structures have geometry, valid paths and medical references; no broad-group/custom inference; correct week rollover")
    }
}
