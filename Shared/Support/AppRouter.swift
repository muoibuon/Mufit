import SwiftUI
import WidgetKit

/// Điều hướng đến từ bên ngoài app (widget, Spotlight…).
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Int { case today, calendar, nutrition, body, insights }

    @Published var selectedTab: Tab = .today
    /// Bật lên khi widget yêu cầu mở thẳng màn thêm bữa ăn.
    @Published var pendingAddMeal = false

    func handle(_ url: URL) {
        guard url.scheme == "fitcore" else { return }
        switch url.host {
        case "addmeal":
            selectedTab = .nutrition
            pendingAddMeal = true
        case "water":
            selectedTab = .today
        default:
            break
        }
    }
}

/// Gọi mỗi khi dữ liệu widget quan tâm thay đổi, để widget vẽ lại ngay
/// thay vì chờ đến mốc làm mới 15 phút.
enum WidgetRefresh {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
