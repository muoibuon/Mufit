import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Nút thêm nước ngay trên widget. Chạy trong tiến trình widget, ghi thẳng vào
/// store dùng chung rồi yêu cầu WidgetKit vẽ lại — người dùng không phải mở app.
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Thêm nước"
    static var description = IntentDescription("Ghi nhận một lượng nước vừa uống.")
    /// Không mở app: mọi thứ xử lý tại chỗ.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Số ml")
    var milliliters: Double

    init() {
        milliliters = 200
    }

    init(milliliters: Double) {
        self.milliliters = milliliters
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedStore.shared.mainContext
        context.insert(HydrationLog(date: .now, milliliters: milliliters))
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Hoàn tác ly nước vừa thêm — bấm nhầm là chuyện thường.
struct UndoLastWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Hoàn tác ly nước cuối"
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedStore.shared.mainContext
        let (start, end) = DayRange.today()
        var descriptor = FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let last = (try? context.fetch(descriptor))?.first {
            context.delete(last)
            try? context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
