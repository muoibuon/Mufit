import Foundation

/// Đọc ghi Firestore qua REST.
///
/// Mỗi phần dữ liệu được lưu thành **một document chứa một chuỗi JSON**, thay vì ánh xạ
/// từng trường sang kiểu dữ liệu riêng của Firestore. Cách này giữ code gọn, tránh phải
/// viết bộ chuyển đổi cho hàng chục thuộc tính, và quan trọng hơn: khi model của app đổi
/// thì không phải sửa cấu trúc trên máy chủ.
struct FirestoreClient {

    struct Document {
        var json: String
        var updatedAt: Date
    }

    enum ClientError: LocalizedError {
        case notConfigured
        case tooLarge(Int)
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Chưa cấu hình Firebase."
            case .tooLarge(let bytes):
                return "Gói dữ liệu \(bytes / 1024) KB vượt giới hạn 1 MB của một document Firestore."
            case .server(let message):
                return "Firestore: \(message)"
            }
        }
    }

    /// Firestore chặn document trên 1 MiB; chừa lại phần cho metadata.
    private static let maxPayloadBytes = 900_000

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func get(path: String, idToken: String) async throws -> Document? {
        guard FirebaseConfig.isConfigured else { throw ClientError.notConfigured }

        var request = URLRequest(url: URL(string: "\(FirebaseConfig.firestoreBase)/\(path)")!)
        request.setValue("Bearer " + idToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }   // chưa từng đồng bộ
            guard (200..<300).contains(http.statusCode) else {
                throw ClientError.server(Self.message(from: data, status: http.statusCode))
            }
        }

        struct Response: Decodable {
            struct Fields: Decodable {
                struct StringField: Decodable { let stringValue: String? }
                struct TimestampField: Decodable { let timestampValue: String? }
                let payload: StringField?
                let updatedAt: TimestampField?
            }
            let fields: Fields?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let json = decoded.fields?.payload?.stringValue
        else { return nil }

        let stamp = decoded.fields?.updatedAt?.timestampValue
            .flatMap { Self.formatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }

        return Document(json: json, updatedAt: stamp ?? .distantPast)
    }

    @discardableResult
    func set(path: String, json: String, idToken: String) async throws -> Date {
        guard FirebaseConfig.isConfigured else { throw ClientError.notConfigured }

        let size = json.utf8.count
        guard size <= Self.maxPayloadBytes else { throw ClientError.tooLarge(size) }

        let now = Date()
        var request = URLRequest(url: URL(string: "\(FirebaseConfig.firestoreBase)/\(path)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer " + idToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "fields": [
                "payload": ["stringValue": json],
                "updatedAt": ["timestampValue": Self.formatter.string(from: now)]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ClientError.server(Self.message(from: data, status: http.statusCode))
        }
        return now
    }

    private static func message(from data: Data, status: Int) -> String {
        struct ErrorBody: Decodable {
            struct Inner: Decodable { let message: String }
            let error: Inner
        }
        if let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data) {
            if decoded.error.message.contains("PERMISSION_DENIED") {
                return "không có quyền ghi. Kiểm tra lại quy tắc bảo mật Firestore."
            }
            return decoded.error.message
        }
        return "mã lỗi \(status)"
    }
}
