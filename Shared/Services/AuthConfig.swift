import Foundation

/// Khoá ứng dụng cho đăng nhập bằng Google và Facebook.
///
/// Hai giá trị này phải do bạn tạo trên cổng của từng nhà cung cấp — không có cách
/// nào lấy tự động, và cũng không nên nhúng khoá của người khác vào app.
///
/// **Google**: Google Cloud Console → APIs & Services → Credentials →
/// Create OAuth client ID → chọn loại **iOS** → Bundle ID `com.muoi.fitcore`.
/// Lấy chuỗi dạng `1234567890-abc...xyz.apps.googleusercontent.com`.
///
/// **Facebook**: developers.facebook.com → Create App → thêm sản phẩm
/// **Facebook Login** → Settings → bật *Client OAuth Login* và *Web OAuth Login*,
/// thêm `fb<APP_ID>://authorize/` vào Valid OAuth Redirect URIs. Lấy **App ID**.
enum AuthConfig {

    /// Dán OAuth Client ID (loại iOS) của Google vào đây.
    static let googleClientID = ""

    /// Dán App ID của Facebook vào đây.
    static let facebookAppID = ""

    /// Google yêu cầu redirect URI là client ID đảo ngược.
    static var googleRedirectScheme: String {
        googleClientID
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
    }

    static var googleRedirectURI: String {
        googleRedirectScheme + ":/oauth2redirect"
    }

    static var facebookRedirectScheme: String { "fb" + facebookAppID }
    static var facebookRedirectURI: String { facebookRedirectScheme + "://authorize/" }

    static var isGoogleConfigured: Bool { !googleClientID.isEmpty }
    static var isFacebookConfigured: Bool { !facebookAppID.isEmpty }
}
