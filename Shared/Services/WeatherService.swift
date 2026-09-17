import Foundation

/// Lấy thời tiết từ Open-Meteo (open-meteo.com) — API mở, không cần API key,
/// dữ liệu gốc từ các mô hình khí tượng quốc gia (DWD ICON, NOAA GFS, Météo-France).
struct WeatherService {

    struct DailyWeather {
        var date: Date
        var meanTempC: Double
        var maxTempC: Double
        var minTempC: Double
        var humidityPercent: Double
        var uvIndexMax: Double
    }

    enum ServiceError: LocalizedError {
        case badResponse
        case noData

        var errorDescription: String? {
            switch self {
            case .badResponse: return "Máy chủ thời tiết trả về lỗi."
            case .noData: return "Không có dữ liệu thời tiết cho vị trí này."
            }
        }
    }

    private struct Response: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double?]
            let temperature_2m_min: [Double?]
            let temperature_2m_mean: [Double?]
            let uv_index_max: [Double?]
        }
        struct Current: Decodable {
            let relative_humidity_2m: Double?
        }
        let daily: Daily
        let current: Current?
    }

    func fetchToday(latitude: Double, longitude: Double) async throws -> DailyWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,temperature_2m_mean,uv_index_max"),
            .init(name: "current", value: "relative_humidity_2m"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "1")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let dayString = decoded.daily.time.first else { throw ServiceError.noData }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dayString) ?? .now

        let maxT = decoded.daily.temperature_2m_max.first.flatMap { $0 } ?? 25
        let minT = decoded.daily.temperature_2m_min.first.flatMap { $0 } ?? 20
        let meanT = decoded.daily.temperature_2m_mean.first.flatMap { $0 } ?? ((maxT + minT) / 2)
        let uv = decoded.daily.uv_index_max.first.flatMap { $0 } ?? 0

        return DailyWeather(
            date: date,
            meanTempC: meanT,
            maxTempC: maxT,
            minTempC: minT,
            humidityPercent: decoded.current?.relative_humidity_2m ?? 60,
            uvIndexMax: uv
        )
    }
}
