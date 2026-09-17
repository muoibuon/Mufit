import Foundation

/// Tính chuỗi ngày (streak) hoàn thành trọn vẹn kế hoạch tập.
///
/// Quy tắc:
/// - Một ngày được tính là "cháy" khi tổng reps thực tế ≥ tổng reps đã set up từ trước
///   (tức hoàn thành 100% tiến độ của buổi tập hôm đó).
/// - Ngày nghỉ (không đặt buổi nào) không làm đứt chuỗi, nhưng cũng không cộng thêm.
///   Nghỉ quá `maxRestGap` ngày liên tiếp thì chuỗi đứt — nghỉ dài là mất nhịp thật.
/// - Ngày hôm nay chưa đạt thì chưa cộng, nhưng cũng chưa làm đứt: người dùng còn
///   cả ngày để hoàn thành.
enum StreakCalculator {

    /// Số ngày nghỉ liên tiếp tối đa còn được bỏ qua.
    static let maxRestGap = 2

    struct Result {
        var current: Int
        var best: Int
        var isLitToday: Bool
        var todayProgress: Double
        var hasPlanToday: Bool
        var message: String
    }

    /// Tiến độ của một ngày: tổng reps thực tế / tổng reps dự kiến của mọi buổi trong ngày.
    static func progress(on day: Date, sessions: [WorkoutSession]) -> Double? {
        let daySessions = sessions.filter { $0.date.isSameDay(as: day) && $0.status != .skipped }
        guard !daySessions.isEmpty else { return nil }

        let planned = daySessions.reduce(0) { $0 + $1.plannedRepTotal }
        guard planned > 0 else { return nil }

        let actual = daySessions.reduce(0) { $0 + $1.actualRepTotal }
        return Double(actual) / Double(planned)
    }

    static func evaluate(sessions: [WorkoutSession], today: Date = .now) -> Result {
        let todayProgress = progress(on: today, sessions: sessions) ?? 0
        let hasPlanToday = progress(on: today, sessions: sessions) != nil
        let isLit = todayProgress >= 1.0

        var current = 0
        var restRun = 0
        var offset = 0

        // Hôm nay chưa đạt thì bắt đầu đếm từ hôm qua, không tính là đứt chuỗi.
        if !isLit { offset = 1 }

        while offset < 400 {
            let day = today.adding(days: -offset)
            if let p = progress(on: day, sessions: sessions) {
                if p >= 1.0 {
                    current += 1
                    restRun = 0
                } else {
                    break
                }
            } else {
                restRun += 1
                if restRun > maxRestGap { break }
            }
            offset += 1
        }

        return Result(
            current: current,
            best: bestStreak(sessions: sessions, today: today),
            isLitToday: isLit,
            todayProgress: todayProgress,
            hasPlanToday: hasPlanToday,
            message: message(current: current, isLit: isLit, hasPlan: hasPlanToday, progress: todayProgress)
        )
    }

    /// Chuỗi dài nhất từng đạt được, quét toàn bộ lịch sử.
    private static func bestStreak(sessions: [WorkoutSession], today: Date) -> Int {
        guard let earliest = sessions.map(\.date).min() else { return 0 }
        let totalDays = (Calendar.current.dateComponents([.day], from: earliest, to: today).day ?? 0) + 1

        var best = 0
        var run = 0
        var restRun = 0

        for offset in stride(from: totalDays - 1, through: 0, by: -1) {
            let day = today.adding(days: -offset)
            if let p = progress(on: day, sessions: sessions) {
                if p >= 1.0 {
                    run += 1
                    restRun = 0
                    best = max(best, run)
                } else {
                    run = 0
                    restRun = 0
                }
            } else {
                restRun += 1
                if restRun > maxRestGap { run = 0 }
            }
        }
        return best
    }

    private static func message(current: Int, isLit: Bool, hasPlan: Bool, progress: Double) -> String {
        if isLit {
            switch current {
            case 1: return "Ngọn lửa đã cháy. Giữ thêm ngày nữa để thành chuỗi thật sự."
            case 2...6: return "Chuỗi \(current) ngày đang cháy. Đừng để tắt."
            case 7...29: return "\(current) ngày liên tiếp hoàn thành 100% kế hoạch. Rất khó bỏ dở ở mức này."
            default: return "\(current) ngày. Đây là thói quen, không còn là nỗ lực nữa."
            }
        }
        if !hasPlan {
            return current > 0
                ? "Hôm nay chưa có lịch tập. Chuỗi \(current) ngày vẫn giữ, nhưng nghỉ quá \(maxRestGap) ngày là đứt."
                : "Chưa có lịch tập nào. Setup một buổi để bắt đầu chuỗi."
        }
        if progress <= 0 {
            return current > 0
                ? "Chuỗi \(current) ngày đang chờ bạn. Hoàn thành 100% buổi hôm nay để thắp lại lửa."
                : "Hoàn thành 100% reps đã set up để thắp lửa."
        }
        let remaining = Int((1 - progress) * 100)
        return "Còn \(remaining)% nữa là đủ 100% kế hoạch hôm nay — lửa sẽ cháy."
    }
}
