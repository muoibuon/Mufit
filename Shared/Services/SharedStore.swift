import Foundation
import SwiftData

/// Kho dữ liệu dùng chung giữa app và widget.
///
/// Store đặt trong App Group container để tiến trình widget mở được cùng một file
/// SwiftData với app — nhờ vậy widget đọc được bữa ăn, nước uống theo thời gian thực
/// và nút thêm nước trên widget ghi thẳng vào đúng kho đó.
enum SharedStore {

    static let appGroupID = "group.com.muoi.fitcore"

    static let schema = Schema([
        UserProfile.self,
        BodyMeasurement.self,
        Exercise.self,
        WorkoutSession.self,
        SessionExercise.self,
        SetLog.self,
        FoodItem.self,
        MealEntry.self,
        FoodPortion.self,
        Supplement.self,
        HydrationLog.self,
        SunExposureLog.self,
        WeatherSnapshot.self,
        MovementLog.self
    ])

    /// Container dùng chung. Nếu App Group không khả dụng (thiếu entitlement, hoặc
    /// đang chạy trong môi trường hạn chế) thì lùi về store cục bộ để app vẫn mở được.
    static func makeContainer() -> ModelContainer {
        // Phải hỏi hệ thống xem App Group có hiệu lực không TRƯỚC khi dựng container.
        // Thiếu entitlement thì SwiftData *dừng chương trình* chứ không ném lỗi, nên
        // `try?` hoàn toàn vô tác dụng — app tắt ngay trong init, chưa kịp vẽ gì.
        // Bản cài bằng tài khoản Apple miễn phí chính là trường hợp đó.
        let hasAppGroup = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil

        if hasAppGroup,
           let shared = try? ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
           ) {
            return shared
        }

        if let local = try? ModelContainer(for: schema) {
            return local
        }

        // Cùng lắm thì dựng store trong bộ nhớ để app không chết khi mở.
        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    /// Container riêng cho widget: chỉ đọc, không cần seed dữ liệu.
    @MainActor
    static let shared: ModelContainer = makeContainer()
}

/// Các mốc thời gian dùng chung cho truy vấn "hôm nay".
enum DayRange {
    static func today() -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }
}
