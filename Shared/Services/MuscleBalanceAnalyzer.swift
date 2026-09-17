import Foundation

/// Phát hiện nhóm cơ bị bỏ quên và mất cân đối đẩy/kéo.
///
/// Nền: ACSM Position Stand 2011 khuyến nghị mỗi nhóm cơ lớn được tập
/// 2-3 buổi/tuần; tỉ lệ khối lượng kéo/đẩy lệch nhiều gắn với đau vai và tư thế xấu.
enum MuscleBalanceAnalyzer {

    struct MuscleStat: Identifiable {
        var id: String { muscle.rawValue }
        var muscle: MuscleGroup
        var sessionCount: Int
        var totalSets: Int
        var volumeKg: Double
    }

    struct Alert: Identifiable {
        enum Severity { case info, warning, critical }
        var id = UUID()
        var title: String
        var detail: String
        var severity: Severity
    }

    /// Thống kê theo nhóm cơ trong khoảng `days` ngày gần nhất.
    static func stats(sessions: [WorkoutSession], days: Int = 14) -> [MuscleStat] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let recent = sessions.filter { $0.date >= cutoff && $0.status == .completed }

        var counts: [MuscleGroup: (sessions: Set<Int>, sets: Int, volume: Double)] = [:]

        for (idx, session) in recent.enumerated() {
            for se in session.orderedExercises {
                guard let ex = se.exercise else { continue }
                let completed = se.orderedSets.filter(\.isCompleted)
                guard !completed.isEmpty else { continue }
                let volume = completed.reduce(0) { $0 + $1.volumeKg }

                var entry = counts[ex.primaryMuscle] ?? ([], 0, 0)
                entry.sessions.insert(idx)
                entry.sets += completed.count
                entry.volume += volume
                counts[ex.primaryMuscle] = entry

                // Nhóm cơ phụ tính nửa trọng số.
                for sec in ex.secondaryMuscles {
                    var s = counts[sec] ?? ([], 0, 0)
                    s.sessions.insert(idx)
                    s.sets += completed.count / 2
                    s.volume += volume * 0.4
                    counts[sec] = s
                }
            }
        }

        return MuscleGroup.allCases.map { m in
            let e = counts[m]
            return MuscleStat(
                muscle: m,
                sessionCount: e?.sessions.count ?? 0,
                totalSets: e?.sets ?? 0,
                volumeKg: e?.volume ?? 0
            )
        }
    }

    /// Sinh cảnh báo dựa trên lịch đã set up so với thực tế đã tập.
    static func alerts(sessions: [WorkoutSession], days: Int = 14) -> [Alert] {
        var alerts: [Alert] = []
        let weeks = Double(days) / 7
        let all = stats(sessions: sessions, days: days)

        // 1. Nhóm cơ lớn bị bỏ quên hoàn toàn.
        let neglected = all.filter { $0.muscle.isMajor && $0.sessionCount == 0 }
        if !neglected.isEmpty {
            alerts.append(Alert(
                title: "Bỏ quên \(neglected.count) nhóm cơ lớn",
                detail: neglected.map(\.muscle.label).joined(separator: ", ")
                    + " chưa được tập buổi nào trong \(days) ngày qua. ACSM khuyến nghị mỗi nhóm cơ lớn tập tối thiểu 2 buổi/tuần.",
                severity: .critical
            ))
        }

        // 2. Nhóm cơ lớn dưới tần suất tối thiểu.
        let under = all.filter { $0.muscle.isMajor && $0.sessionCount > 0 && Double($0.sessionCount) / weeks < 2 }
        if !under.isEmpty {
            alerts.append(Alert(
                title: "Tần suất thấp ở \(under.count) nhóm cơ",
                detail: under
                    .map { "\($0.muscle.label) (\(String(format: "%.1f", Double($0.sessionCount) / weeks)) buổi/tuần)" }
                    .joined(separator: ", ")
                    + " — chưa đạt mốc 2 buổi/tuần.",
                severity: .warning
            ))
        }

        // 3. Mất cân đối đẩy/kéo.
        let push = volume(all, [.chest, .shoulders, .triceps])
        let pull = volume(all, [.back, .biceps])
        if push > 0 && pull > 0 {
            let ratio = push / pull
            if ratio > 1.6 {
                alerts.append(Alert(
                    title: "Đẩy nhiều hơn kéo",
                    detail: "Khối lượng đẩy gấp \(String(format: "%.1f", ratio)) lần kéo. Lệch kéo dài dễ kéo vai ra trước và gây đau vai. Nên đưa tỉ lệ về khoảng 1:1 đến 1:1.3.",
                    severity: .warning
                ))
            } else if ratio < 0.6 {
                alerts.append(Alert(
                    title: "Kéo nhiều hơn đẩy",
                    detail: "Khối lượng kéo gấp \(String(format: "%.1f", 1 / ratio)) lần đẩy. Cân nhắc bổ sung bài đẩy để cân bằng.",
                    severity: .info
                ))
            }
        }

        // 4. Mất cân đối thân trên / thân dưới.
        let upper = volume(all, [.chest, .back, .shoulders, .biceps, .triceps])
        let lower = volume(all, [.quads, .hamstrings, .glutes, .calves])
        if upper > 0 && lower > 0 && upper / lower > 2.5 {
            alerts.append(Alert(
                title: "Thân dưới bị bỏ bê",
                detail: "Khối lượng thân trên gấp \(String(format: "%.1f", upper / lower)) lần thân dưới. Tập chân đều đặn cải thiện mật độ xương và chuyển hoá glucose.",
                severity: .warning
            ))
        }

        // 5. Đùi trước / đùi sau.
        let quad = volume(all, [.quads])
        let ham = volume(all, [.hamstrings])
        if quad > 0 && ham > 0 && quad / ham > 3 {
            alerts.append(Alert(
                title: "Đùi sau yếu so với đùi trước",
                detail: "Tỉ lệ \(String(format: "%.1f", quad / ham)):1. Tỉ lệ lệch nhiều là yếu tố nguy cơ chấn thương dây chằng chéo trước và căng cơ đùi sau.",
                severity: .warning
            ))
        }

        if alerts.isEmpty {
            alerts.append(Alert(
                title: "Phân bổ nhóm cơ cân đối",
                detail: "Trong \(days) ngày qua mọi nhóm cơ lớn đều được tập đủ tần suất. Giữ nhịp này.",
                severity: .info
            ))
        }

        return alerts
    }

    private static func volume(_ stats: [MuscleStat], _ groups: [MuscleGroup]) -> Double {
        stats.filter { groups.contains($0.muscle) }.reduce(0) { $0 + $1.volumeKg }
    }

    /// Hiệu suất tập trung bình: reps thực tế / reps dự kiến.
    static func averageCompletionRate(sessions: [WorkoutSession], days: Int = 14) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let done = sessions.filter { $0.date >= cutoff && $0.status == .completed && $0.plannedRepTotal > 0 }
        guard !done.isEmpty else { return 0 }
        return done.reduce(0) { $0 + $1.completionRate } / Double(done.count)
    }
}
