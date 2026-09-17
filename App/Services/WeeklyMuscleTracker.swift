import Foundation

/// Calendar weeks, never a rolling seven-day window. History is not mutated at rollover.
enum WeeklyMuscleTracker {
    static let muscles = MuscleGroup.allCases.filter { $0 != .fullBody && $0 != .cardio }

    struct Activity {
        var primary: MuscleGroup
        var secondary: [MuscleGroup]
        var workingSets: Int
    }

    struct Record {
        var date: Date
        var completed: Bool
        var activities: [Activity]
    }

    struct Stat: Identifiable {
        var id: String { muscle.rawValue }
        var muscle: MuscleGroup
        var sessions = 0
        var days = 0
        var directSets = 0
        var assistingSets = 0
        var lastTrained: Date?
        var trained: Bool { sessions > 0 }
    }

    static func calendar(timeZone: TimeZone = .autoupdatingCurrent) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func week(containing date: Date, calendar: Calendar = calendar()) -> DateInterval {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: day)!
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }

    static func stats(records: [Record], now: Date = .now, calendar: Calendar = calendar()) -> [Stat] {
        let interval = week(containing: now, calendar: calendar)
        let current = records.filter {
            $0.completed && $0.date >= interval.start && $0.date < interval.end && $0.date <= now
        }
        return muscles.map { muscle in
            var stat = Stat(muscle: muscle)
            var days = Set<Date>()
            for record in current {
                var touched = false
                for activity in record.activities where activity.workingSets > 0 {
                    if activity.primary == muscle {
                        stat.directSets += activity.workingSets
                        touched = true
                    } else if activity.secondary.contains(muscle) {
                        stat.assistingSets += activity.workingSets
                        touched = true
                    }
                }
                if touched {
                    stat.sessions += 1
                    days.insert(calendar.startOfDay(for: record.date))
                    stat.lastTrained = max(stat.lastTrained ?? record.date, record.date)
                }
            }
            stat.days = days.count
            return stat
        }
    }
}
