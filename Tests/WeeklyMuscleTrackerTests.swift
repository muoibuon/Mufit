import Foundation

@main
struct WeeklyMuscleTrackerTests {
    static func main() {
        let formatter = ISO8601DateFormatter()
        func date(_ value: String) -> Date { formatter.date(from: value)! }
        let calendar = WeeklyMuscleTracker.calendar(timeZone: TimeZone(identifier: "Asia/Ho_Chi_Minh")!)
        let sunday = date("2026-09-20T23:59:59+07:00")
        let monday = date("2026-09-21T00:00:00+07:00")
        let first = date("2026-09-14T00:00:00+07:00")
        let activity = WeeklyMuscleTracker.Activity(primary: .chest, secondary: [.triceps, .triceps, .chest], workingSets: 3)
        let records = [WeeklyMuscleTracker.Record(date: first, completed: true, activities: [activity, activity])]
        func stats(_ entries: [WeeklyMuscleTracker.Record], _ now: Date) -> [WeeklyMuscleTracker.Stat] {
            WeeklyMuscleTracker.stats(records: entries, now: now, calendar: calendar)
        }
        func chest(_ values: [WeeklyMuscleTracker.Stat]) -> WeeklyMuscleTracker.Stat { values.first { $0.muscle == .chest }! }
        let current = stats(records, sunday)
        assert(chest(current).sessions == 1 && chest(current).directSets == 6)
        assert(chest(current).assistingSets == 0)
        assert(current.first { $0.muscle == .triceps }!.assistingSets == 6)
        assert(chest(current).trained, "Monday training must remain checked on Sunday")
        assert(!chest(stats(records, monday)).trained, "Monday midnight starts a fresh week")
        assert(chest(stats(records, sunday)).trained, "Rollover must not destroy old history")
        let sameDay = records + [.init(date: first.addingTimeInterval(3600), completed: true, activities: [activity])]
        assert(chest(stats(sameDay, sunday)).days == 1 && chest(stats(sameDay, sunday)).sessions == 2)
        let secondDay = sameDay + [.init(date: first.addingTimeInterval(86400), completed: true, activities: [activity])]
        assert(chest(stats(secondDay, sunday)).days == 2)
        let invalid: [WeeklyMuscleTracker.Record] = [
            .init(date: first.addingTimeInterval(-1), completed: true, activities: [activity]),
            .init(date: monday, completed: true, activities: [activity]),
            .init(date: sunday, completed: false, activities: [activity]),
            .init(date: sunday, completed: true, activities: [.init(primary: .chest, secondary: [.triceps], workingSets: 0)]),
            .init(date: sunday, completed: true, activities: [.init(primary: .fullBody, secondary: [], workingSets: 3)])
        ]
        assert(stats(invalid, sunday).allSatisfy { !$0.trained })
        assert(!chest(stats([.init(date: sunday, completed: true, activities: [activity])], first)).trained)
        let week = WeeklyMuscleTracker.week(containing: date("2027-01-01T10:00:00+07:00"), calendar: calendar)
        assert(week.start == date("2026-12-28T00:00:00+07:00"))
        let dstCalendar = WeeklyMuscleTracker.calendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        let dst = WeeklyMuscleTracker.week(containing: date("2026-03-08T12:00:00-07:00"), calendar: dstCalendar)
        assert(dst.end == date("2026-03-09T00:00:00-07:00"))
        assert(dst.duration == 167 * 3600, "DST week must use calendar arithmetic")
        print("PASS: week persistence, Monday rollover, history, distinct days, direct/assisting sets, invalid/future records, fullBody, year boundary, DST")
    }
}
