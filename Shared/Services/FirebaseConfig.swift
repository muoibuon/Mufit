import Foundation

/// Cấu hình Firebase.
///
/// App dùng **REST API** của Firebase thay vì SDK chính thức: chỉ cần hai chuỗi dưới
/// đây, không phải kéo hàng chục megabyte thư viện vào dự án, và không phụ thuộc
/// vào việc tải gói qua mạng lúc build.
///
/// **Lấy ở đâu** — console.firebase.google.com → tạo project (gói Spark, miễn phí):
/// 1. Project settings → General → *Project ID* (ví dụ `fitcore-1a2b3`)
/// 2. Cùng trang → mục *Web API Key* (chuỗi bắt đầu bằng `AIza...`)
/// 3. Build → Authentication → Sign-in method → bật **Google**, **Facebook**, **Apple**
/// 4. Build → Firestore Database → Create database → chọn chế độ *production*
///
/// **Quy tắc bảo mật Firestore** cần đặt như sau để mỗi người chỉ đọc/ghi được dữ liệu
/// của chính mình:
/// ```
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     match /users/{uid}/{document=**} {
///       allow read, write: if request.auth != null && request.auth.uid == uid;
///     }
///   }
/// }
/// ```
enum FirebaseConfig {

    static let projectID = ""
    static let webAPIKey = ""

    static var isConfigured: Bool { !projectID.isEmpty && !webAPIKey.isEmpty }

    static var identityToolkitBase: String { "https://identitytoolkit.googleapis.com/v1" }
    static var secureTokenBase: String { "https://securetoken.googleapis.com/v1" }

    static var firestoreBase: String {
        "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"
    }
}
