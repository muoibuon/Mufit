import Foundation
import CoreLocation
import Combine

/// Theo dõi vị trí để biết người dùng có ra ngoài vận động hay không.
///
/// Dùng `startMonitoringSignificantLocationChanges` thay vì cập nhật liên tục:
/// đủ để phát hiện "có di chuyển" mà gần như không tốn pin.
@MainActor
final class LocationActivityService: NSObject, ObservableObject {

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var distanceTodayMeters: Double = 0
    @Published private(set) var isTracking = false
    /// Bật lên khi phát hiện di chuyển đáng kể và chưa hỏi về phơi nắng hôm nay.
    @Published var shouldAskAboutSunExposure = false

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var trackingDayKey: String = ""
    private var hasAskedToday = false

    /// Ngưỡng coi là "đã ra ngoài vận động" — 800 m trong ngày.
    private let movementThresholdMeters: Double = 800

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        trackingDayKey = Self.dayKey(for: .now)
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard !isTracking else { return }
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.startUpdatingLocation()
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
        isTracking = true
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        isTracking = false
    }

    func requestOneShotLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.requestLocation()
    }

    func markSunPromptAnswered() {
        hasAskedToday = true
        shouldAskAboutSunExposure = false
    }

    private func rollDayIfNeeded() {
        let today = Self.dayKey(for: .now)
        guard today != trackingDayKey else { return }
        trackingDayKey = today
        distanceTodayMeters = 0
        hasAskedToday = false
        lastLocation = nil
    }

    private static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    fileprivate func ingest(_ location: CLLocation) {
        rollDayIfNeeded()
        currentLocation = location

        if let last = lastLocation {
            let delta = location.distance(from: last)
            // Bỏ qua nhảy GPS phi lý (> 5 km giữa hai mẫu liên tiếp gần nhau).
            if delta > 20 && delta < 5000 {
                distanceTodayMeters += delta
            }
        }
        lastLocation = location

        if distanceTodayMeters >= movementThresholdMeters && !hasAskedToday {
            shouldAskAboutSunExposure = true
        }
    }
}

extension LocationActivityService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.ingest(latest) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Lỗi định vị tạm thời là chuyện thường (trong nhà, mất tín hiệu) — bỏ qua.
    }
}
