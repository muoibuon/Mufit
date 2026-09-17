import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI

/// Nhà cung cấp danh tính.
enum AuthProvider: String, Codable, CaseIterable, Identifiable {
    case apple, google, facebook, guest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apple: return "Apple ID"
        case .google: return "Google"
        case .facebook: return "Facebook"
        case .guest: return "Không đăng nhập"
        }
    }
}

/// Người dùng đã đăng nhập.
struct AuthUser: Codable, Equatable {
    var id: String
    var provider: AuthProvider
    var email: String?
    var name: String?
    var avatarURL: String?
    var signedInAt: Date
    /// uid do Firebase cấp; giống nhau trên mọi thiết bị của cùng một tài khoản.
    var firebaseUID: String?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let email, !email.isEmpty { return email }
        return provider == .guest ? "Khách" : "Người dùng"
    }
}

/// Đăng nhập bằng OAuth 2.0 qua `ASWebAuthenticationSession`.
///
/// Không dùng SDK của Google hay Facebook: cả hai đều hỗ trợ luồng OAuth chuẩn qua
/// trình duyệt hệ thống, nên app chỉ cần Client ID / App ID mà không phải kéo thêm
/// thư viện bên thứ ba vào dự án. Google dùng Authorization Code + PKCE (khuyến nghị
/// hiện hành cho app di động, không cần client secret); Facebook dùng luồng implicit.
@MainActor
final class AuthService: NSObject, ObservableObject {

    enum AuthError: LocalizedError {
        case notConfigured(AuthProvider)
        case cancelled
        case invalidResponse
        case network(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured(let p):
                return "Đăng nhập \(p.label) chưa sẵn sàng — thiếu khoá ứng dụng. Hướng dẫn lấy khoá nằm trong AuthConfig.swift."
            case .cancelled:
                return "Đã huỷ đăng nhập."
            case .invalidResponse:
                return "Nhà cung cấp trả về dữ liệu không hợp lệ."
            case .network(let message):
                return message
            }
        }
    }

    private static let userKey = "currentUser"
    private static let tokenKey = "accessToken"
    private static let firebaseKey = "firebaseSession"

    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var firebaseSession: FirebaseAuthClient.Session?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private var webSession: ASWebAuthenticationSession?
    private var appleDelegate: AppleSignInDelegate?
    private let firebase = FirebaseAuthClient()

    override init() {
        super.init()
        currentUser = Keychain.object(AuthUser.self, for: Self.userKey)
        firebaseSession = Keychain.object(FirebaseAuthClient.Session.self, for: Self.firebaseKey)
    }

    var isSignedIn: Bool { currentUser != nil }

    // MARK: - Đăng nhập

    func signInAsGuest() {
        let user = AuthUser(id: "guest-" + UUID().uuidString, provider: .guest,
                            email: nil, name: nil, avatarURL: nil, signedInAt: .now,
                            firebaseUID: nil)
        persist(user, token: nil)
    }

    func signIn(with provider: AuthProvider) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            switch provider {
            case .apple: try await signInWithApple()
            case .google: try await signInWithGoogle()
            case .facebook: try await signInWithFacebook()
            case .guest: signInAsGuest()
            }
        } catch AuthError.cancelled {
            // Người dùng tự đóng cửa sổ — không phải lỗi, không cần báo.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        Keychain.remove(Self.userKey)
        Keychain.remove(Self.tokenKey)
        Keychain.remove(Self.firebaseKey)
        currentUser = nil
        firebaseSession = nil
    }

    /// Đang đăng nhập bằng tài khoản thật và đã nối được với Firebase.
    var canSync: Bool { firebaseSession != nil }

    /// Trả về idToken còn hạn, tự làm mới nếu cần. Token Firebase chỉ sống 1 giờ.
    func currentIDToken() async -> String? {
        guard var session = firebaseSession else { return nil }
        guard session.isExpired else { return session.idToken }

        do {
            session = try await firebase.refresh(session)
            firebaseSession = session
            Keychain.setObject(session, for: Self.firebaseKey)
            return session.idToken
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Đổi token của nhà cung cấp lấy danh tính Firebase. Chưa cấu hình Firebase thì
    /// bỏ qua lặng lẽ — app vẫn dùng được ở chế độ chỉ lưu trên máy.
    private func linkFirebase(providerID: String, postBody: String, user: AuthUser) async -> AuthUser {
        guard FirebaseConfig.isConfigured else { return user }
        do {
            let session = try await firebase.signInWithIdP(providerID: providerID, postBody: postBody)
            firebaseSession = session
            Keychain.setObject(session, for: Self.firebaseKey)

            var linked = user
            linked.firebaseUID = session.uid
            if linked.email == nil { linked.email = session.email }
            if linked.name == nil { linked.name = session.displayName }
            return linked
        } catch {
            errorMessage = error.localizedDescription
            return user
        }
    }

    private func persist(_ user: AuthUser, token: String?) {
        Keychain.setObject(user, for: Self.userKey)
        if let token, let data = token.data(using: .utf8) {
            Keychain.set(data, for: Self.tokenKey)
        }
        currentUser = user
    }

    // MARK: - Apple ID / iCloud

    /// Sign in with Apple chạy hoàn toàn trên thiết bị qua tài khoản iCloud đang
    /// đăng nhập — không cần Client ID hay máy chủ trung gian như Google/Facebook.
    /// Apple chỉ trả tên và email ở **lần cấp quyền đầu tiên**, nên lần đó phải lưu lại.
    private func signInWithApple() async throws {
        let rawNonce = Self.randomCodeVerifier()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Apple nhận bản băm; Firebase đối chiếu lại bằng chuỗi gốc.
        request.nonce = Self.sha256Hex(rawNonce)

        let credential = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            appleDelegate = delegate
            controller.delegate = delegate
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        var name: String?
        if let components = credential.fullName {
            let parts = [components.familyName, components.givenName].compactMap { $0 }
            if !parts.isEmpty { name = parts.joined(separator: " ") }
        }

        // Lần đăng nhập sau Apple không gửi lại tên/email, nên giữ thông tin đã lưu.
        let previous = Keychain.object(AuthUser.self, for: Self.userKey)
        let keepSame = previous?.id == credential.user

        let user = AuthUser(
            id: credential.user,
            provider: .apple,
            email: credential.email ?? (keepSame ? previous?.email : nil),
            name: name ?? (keepSame ? previous?.name : nil),
            avatarURL: keepSame ? previous?.avatarURL : nil,
            signedInAt: .now,
            firebaseUID: nil
        )

        let token = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        var linked = user
        if let token {
            linked = await linkFirebase(providerID: "apple.com",
                                        postBody: "id_token=\(token)&nonce=\(rawNonce)",
                                        user: user)
        }
        persist(linked, token: token)
    }

    // MARK: - Google (Authorization Code + PKCE)

    private func signInWithGoogle() async throws {
        guard AuthConfig.isGoogleConfigured else { throw AuthError.notConfigured(.google) }

        let verifier = Self.randomCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: AuthConfig.googleClientID),
            .init(name: "redirect_uri", value: AuthConfig.googleRedirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256")
        ]

        let callback = try await presentWebAuth(
            url: components.url!,
            scheme: AuthConfig.googleRedirectScheme
        )

        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw AuthError.invalidResponse }

        let tokens = try await exchangeGoogleCode(code, verifier: verifier)
        var profile = try await fetchGoogleProfile(accessToken: tokens.accessToken)
        if let idToken = tokens.idToken {
            profile = await linkFirebase(providerID: "google.com",
                                         postBody: "id_token=" + idToken,
                                         user: profile)
        }
        persist(profile, token: tokens.accessToken)
    }

    private func exchangeGoogleCode(_ code: String, verifier: String) async throws -> (accessToken: String, idToken: String?) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = URLComponents()
        body.queryItems = [
            .init(name: "code", value: code),
            .init(name: "client_id", value: AuthConfig.googleClientID),
            .init(name: "redirect_uri", value: AuthConfig.googleRedirectURI),
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code_verifier", value: verifier)
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.network("Google từ chối đổi mã đăng nhập.")
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let id_token: String?
        }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw AuthError.invalidResponse
        }
        return (decoded.access_token, decoded.id_token)
    }

    private func fetchGoogleProfile(accessToken: String) async throws -> AuthUser {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        struct Profile: Decodable {
            let sub: String
            let email: String?
            let name: String?
            let picture: String?
        }
        guard let p = try? JSONDecoder().decode(Profile.self, from: data) else {
            throw AuthError.invalidResponse
        }
        return AuthUser(id: p.sub, provider: .google, email: p.email,
                        name: p.name, avatarURL: p.picture, signedInAt: .now, firebaseUID: nil)
    }

    // MARK: - Facebook (implicit flow)

    private func signInWithFacebook() async throws {
        guard AuthConfig.isFacebookConfigured else { throw AuthError.notConfigured(.facebook) }

        var components = URLComponents(string: "https://www.facebook.com/v21.0/dialog/oauth")!
        components.queryItems = [
            .init(name: "client_id", value: AuthConfig.facebookAppID),
            .init(name: "redirect_uri", value: AuthConfig.facebookRedirectURI),
            .init(name: "response_type", value: "token"),
            .init(name: "scope", value: "public_profile,email")
        ]

        let callback = try await presentWebAuth(
            url: components.url!,
            scheme: AuthConfig.facebookRedirectScheme
        )

        // Facebook trả token trong fragment (#access_token=...), không phải query.
        guard let fragment = callback.fragment else { throw AuthError.invalidResponse }
        var parsed: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                parsed[String(parts[0])] = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            }
        }
        guard let token = parsed["access_token"] else { throw AuthError.invalidResponse }

        var profile = try await fetchFacebookProfile(accessToken: token)
        profile = await linkFirebase(providerID: "facebook.com",
                                     postBody: "access_token=" + token,
                                     user: profile)
        persist(profile, token: token)
    }

    private func fetchFacebookProfile(accessToken: String) async throws -> AuthUser {
        var components = URLComponents(string: "https://graph.facebook.com/v21.0/me")!
        components.queryItems = [
            .init(name: "fields", value: "id,name,email,picture.type(large)"),
            .init(name: "access_token", value: accessToken)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        struct Picture: Decodable { struct Data: Decodable { let url: String? }; let data: Data }
        struct Profile: Decodable {
            let id: String
            let name: String?
            let email: String?
            let picture: Picture?
        }
        guard let p = try? JSONDecoder().decode(Profile.self, from: data) else {
            throw AuthError.invalidResponse
        }
        return AuthUser(id: p.id, provider: .facebook, email: p.email,
                        name: p.name, avatarURL: p.picture?.data.url, signedInAt: .now, firebaseUID: nil)
    }

    // MARK: - Cửa sổ đăng nhập hệ thống

    private func presentWebAuth(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                } else {
                    continuation.resume(throwing: AuthError.network(error?.localizedDescription ?? "Không mở được cửa sổ đăng nhập."))
                }
            }
            session.presentationContextProvider = self
            // Không dùng phiên duyệt web chung để tài khoản đăng nhập không bị lẫn
            // với tài khoản đang mở trong Safari.
            session.prefersEphemeralWebBrowserSession = true
            webSession = session
            session.start()
        }
    }

    // MARK: - PKCE

    private static func randomCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    /// Apple yêu cầu nonce ở dạng chuỗi hex của SHA256.
    private static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncoded()
    }
}

/// Giữ continuation cho luồng uỷ quyền của Apple, vốn chỉ trả kết quả qua delegate.
private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    private var hasResumed = false

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !hasResumed else { return }
        hasResumed = true
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: AuthService.AuthError.invalidResponse)
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        guard !hasResumed else { return }
        hasResumed = true
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation.resume(throwing: AuthService.AuthError.cancelled)
        } else {
            continuation.resume(throwing: AuthService.AuthError.network(error.localizedDescription))
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { Self.keyWindow() }
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { Self.keyWindow() }
    }
}

extension AuthService {
    @MainActor
    static func keyWindow() -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension Data {
    /// Base64 dạng URL-safe, bỏ ký tự đệm — đúng chuẩn PKCE (RFC 7636).
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
