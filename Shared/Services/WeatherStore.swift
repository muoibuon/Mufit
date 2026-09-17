import Foundation
import SwiftData
import CoreLocation

/// Giữ snapshot thời tiết của hôm nay, cache vào SwiftData để chỉ gọi API 1 lần/ngày.
@MainActor
final class WeatherStore: ObservableObject {

    @Published private(set) var today: WeatherSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service = WeatherService()

    nonisolated static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func loadCached(context: ModelContext) {
        let key = Self.dayKey(for: .now)
        var descriptor = FetchDescriptor<WeatherSnapshot>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        today = (try? context.fetch(descriptor))?.first
    }

    /// Làm mới từ API. Nếu chưa có toạ độ thì dùng mặc định Hà Nội để app vẫn có số liệu.
    func refresh(context: ModelContext, coordinate: CLLocationCoordinate2D?, force: Bool = false) async {
        let key = Self.dayKey(for: .now)
        if !force {
            loadCached(context: context)
            if today != nil { return }
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let coord = coordinate ?? CLLocationCoordinate2D(latitude: 21.0278, longitude: 105.8342)

        do {
            let w = try await service.fetchToday(latitude: coord.latitude, longitude: coord.longitude)

            var descriptor = FetchDescriptor<WeatherSnapshot>(predicate: #Predicate { $0.dayKey == key })
            descriptor.fetchLimit = 1
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.meanTempC = w.meanTempC
                existing.maxTempC = w.maxTempC
                existing.minTempC = w.minTempC
                existing.humidityPercent = w.humidityPercent
                existing.uvIndexMax = w.uvIndexMax
                existing.latitude = coord.latitude
                existing.longitude = coord.longitude
                today = existing
            } else {
                let snapshot = WeatherSnapshot(
                    dayKey: key,
                    date: w.date,
                    meanTempC: w.meanTempC,
                    maxTempC: w.maxTempC,
                    minTempC: w.minTempC,
                    humidityPercent: w.humidityPercent,
                    uvIndexMax: w.uvIndexMax,
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
                context.insert(snapshot)
                today = snapshot
            }
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
