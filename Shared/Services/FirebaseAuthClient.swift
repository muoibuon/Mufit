import Foundation

/// Đổi thông tin đăng nhập của Google/Facebook/Apple lấy danh tính Firebase.
///
/// Firebase gọi đây là *sign-in with IdP*: app đã tự lấy được token từ nhà cung cấp,
/// giờ gửi token đó cho Firebase để nhận về `uid` cùng `idToken` dùng khi đọc ghi
/// Firestore. Nhờ vậy cùng một người đăng nhập bằng Google trên iPhone và trên máy
/// khác vẫn ra đúng một `uid`, tức là cùng một kho dữ liệu.
struct FirebaseAuthClient {

    struct Session: Codable, Equatable {
        var uid: String
        var idToken: String
        var refreshToken: String
        var expiresAt: Date
        var email: String?
        var displayName: String?
        var photoURL: String?

        var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
    }

    enum ClientError: LocalizedError {
        case notConfigured
        case server(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Chưa điền Project ID và Web API Key trong FirebaseConfig.swift."
            case .server(let message):
                return "Firebase từ chối: \(message)"
            case .invalidResponse:
                return "Firebase trả về dữ liệu không đọc được."
            }
        }
    }

    /// `providerId` theo quy ước của Firebase: google.com, facebook.com, apple.com.
    func signInWithIdP(providerID: String, postBody: String) async throws -> Session {
        guard FirebaseConfig.isConfigured else { throw ClientError.notConfigured }

        let url = URL(string: "\(FirebaseConfig.identityToolkitBase)/accounts:signInWithIdp?key=\(FirebaseConfig.webAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "postBody": postBody + "&providerId=" + providerID,
            "requestUri": "http://localhost",
            "returnSecureToken": true,
            "returnIdpCredential": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.throwIfError(data: data, response: response)

        struct Response: Decodable {
            let localId: String
            let idToken: String
            let refreshToken: String
            let expiresIn: String
            let email: String?
            let displayName: String?
            let photoUrl: String?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw ClientError.invalidResponse
        }

        return Session(
            uid: decoded.localId,
            idToken: decoded.idToken,
            refreshToken: decoded.refreshToken,
            expiresAt: Date().addingTimeInterval(Double(decoded.expiresIn) ?? 3600),
            email: decoded.email,
            displayName: decoded.displayName,
            photoURL: decoded.photoUrl
        )
    }

    /// idToken chỉ sống 1 giờ; refreshToken dùng để lấy token mới mà không bắt đăng nhập lại.
    func refresh(_ session: Session) async throws -> Session {
        guard FirebaseConfig.isConfigured else { throw ClientError.notConfigured }

        let url = URL(string: "\(FirebaseConfig.secureTokenBase)/token?key=\(FirebaseConfig.webAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = URLComponents()
        body.queryItems = [
            .init(name: "grant_type", value: "refresh_token"),
            .init(name: "refresh_token", value: session.refreshToken)
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.throwIfError(data: data, response: response)

        struct Response: Decodable {
            let id_token: String
            let refresh_token: String
            let expires_in: String
            let user_id: String
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw ClientError.invalidResponse
        }

        var updated = session
        updated.idToken = decoded.id_token
        updated.refreshToken = decoded.refresh_token
        updated.expiresAt = Date().addingTimeInterval(Double(decoded.expires_in) ?? 3600)
        updated.uid = decoded.user_id
        return updated
    }

    private static func throwIfError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        struct ErrorBody: Decodable {
            struct Inner: Decodable { let message: String }
            let error: Inner
        }
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message ?? "mã \(http.statusCode)"
        throw ClientError.server(Self.friendly(message))
    }

    /// Dịch mã lỗi khô khan của Firebase sang câu người dùng hiểu được.
    private static func friendly(_ code: String) -> String {
        switch code {
        case let c where c.contains("OPERATION_NOT_ALLOWED"):
            return "phương thức đăng nhập này chưa được bật trong Firebase Console."
        case let c where c.contains("INVALID_IDP_RESPONSE"):
            return "token từ nhà cung cấp không hợp lệ."
        case let c where c.contains("USER_DISABLED"):
            return "tài khoản đã bị vô hiệu hoá."
        case let c where c.contains("TOKEN_EXPIRED"), let c where c.contains("INVALID_REFRESH_TOKEN"):
            return "phiên đã hết hạn, cần đăng nhập lại."
        default:
            return code
        }
    }
}
