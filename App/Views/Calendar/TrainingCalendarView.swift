import SwiftUI
import SwiftData

struct TrainingCalendarView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var weatherStore: WeatherStore

    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var anchorMonth: Date = Date().startOfDay
    @State private var selectedDate: Date = Date().startOfDay
    @State private var showBuilder = false

    private var bodyWeight: Double { measurements.first?.weightKg ?? 70 }

    private var sessionsForSelectedDay: [WorkoutSession] {
        sessions.filter { $0.date.isSameDay(as: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    CalendarGrid(
                        month: anchorMonth,
                        selected: $selectedDate,
                        markers: markers
                    )
                    .padding(.horizontal, 4)

                    dayDetail
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Lịch tập")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showBuilder = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(isPresented: $showBuilder) {
                SessionBuilderView(date: selectedDate)
            }
        }
    }

    /// Mỗi ngày có buổi tập sẽ có một chấm màu theo trạng thái.
    private var markers: [Date: SessionStatus] {
        var out: [Date: SessionStatus] = [:]
        for s in sessions {
            let key = s.date.startOfDay
            // Ưu tiên hiển thị trạng thái "nặng" nhất của ngày.
            let rank: (SessionStatus) -> Int = { st in
                switch st {
                case .inProgress: return 3
                case .completed: return 2
                case .planned: return 1
                case .skipped: return 0
                }
            }
            if let existing = out[key], rank(existing) >= rank(s.status) { continue }
            out[key] = s.status
        }
        return out
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { anchorMonth = shiftMonth(-1) }
            } label: { Image(systemName: "chevron.left") }

            Spacer()
            Text(Fmt.monthYear.string(from: anchorMonth).capitalized)
                .font(.headline)
            Spacer()

            Button {
                withAnimation { anchorMonth = shiftMonth(1) }
            } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal, 8)
    }

    private func shiftMonth(_ delta: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: delta, to: anchorMonth) ?? anchorMonth
    }

    private var dayDetail: some View {
        Card(title: Fmt.fullDate.string(from: selectedDate).capitalized, systemImage: "calendar.day.timeline.left") {
            if sessionsForSelectedDay.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Chưa có buổi tập nào cho ngày này.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        SessionBuilderView(date: selectedDate)
                    } label: {
                        Label("Setup buổi tập", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                    }
                }
            } else {
                ForEach(sessionsForSelectedDay) { session in
                    NavigationLink {
                        ActiveSessionView(session: session)
                    } label: {
                        SessionRow(
                            session: session,
                            calories: EnergyCalculator.caloriesForSession(
                                session, bodyWeightKg: bodyWeight, weather: weatherStore.today)
                        )
                    }
                    .buttonStyle(.plain)

                    if session.id != sessionsForSelectedDay.last?.id { Divider() }
                }

                NavigationLink {
                    SessionBuilderView(date: selectedDate)
                } label: {
                    Label("Thêm buổi nữa", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .padding(.top, 4)
            }
        }
    }
}

/// Lưới lịch tháng.
struct CalendarGrid: View {
    let month: Date
    @Binding var selected: Date
    let markers: [Date: SessionStatus]

    private let calendar = Calendar.current
    private let weekdaySymbols = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = day.isSameDay(as: selected)
        let isToday = day.isSameDay(as: .now)
        let status = markers[day.startOfDay]

        return Button {
            selected = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.onBrand : (isToday ? Color.brand : .primary))
                Circle()
                    .fill(isSelected ? Color.onBrand : color(for: status))
                    .frame(width: 5, height: 5)
                    .opacity(status == nil ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.brand : (isToday ? Color.brand.mutedFill() : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    private func color(for status: SessionStatus?) -> Color {
        switch status {
        case .completed: return .brandGreen
        case .inProgress: return .brandWarm
        case .planned: return .brand
        case .skipped: return .brandRed
        case nil: return .clear
        }
    }

    /// Danh sách ô của tháng, chèn nil ở đầu cho các ngày trống (tuần bắt đầu Thứ 2).
    private var days: [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: month),
            let firstWeekday = calendar.dateComponents([.weekday], from: interval.start).weekday
        else { return [] }

        // weekday: 1 = CN → cần đổi sang tuần bắt đầu Thứ 2.
        let leading = (firstWeekday + 5) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 30

        var result: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            result.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        return result
    }
}
