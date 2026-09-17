import Foundation
import SwiftData
import SwiftUI

/// Sao lưu và khôi phục dữ liệu người dùng qua Firestore.
///
/// Cách đồng bộ ở đây là **ảnh chụp toàn bộ, ghi đè một chiều** chứ không phải trộn
/// từng bản ghi: mỗi lần đẩy sẽ thay thế bản trên máy chủ, mỗi lần tải sẽ thay thế bản
/// dưới máy. Đủ cho nhu cầu "không mất dữ liệu khi đổi máy", và tránh được toàn bộ
/// lớp lỗi khó chịu của việc hợp nhất tự động. Đổi lại: dùng hai máy cùng lúc thì
/// máy đẩy sau sẽ ghi đè máy đẩy trước.
@MainActor
final class SyncService: ObservableObject {

    enum Status: Equatable {
        case idle
        case working(String)
        case success(String)
        case failure(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var remoteUpdatedAt: Date?

    private let firestore = FirestoreClient()
    private static let lastSyncKey = "lastSyncedAt"

    init() {
        let stored = UserDefaults.standard.double(forKey: Self.lastSyncKey)
        lastSyncedAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    private func documentPath(uid: String) -> String { "users/\(uid)/backup/snapshot" }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Đẩy lên

    func push(context: ModelContext, auth: AuthService) async {
        guard let session = auth.firebaseSession else {
            status = .failure("Chưa đăng nhập bằng tài khoản thật nên chưa có nơi để lưu.")
            return
        }
        guard let token = await auth.currentIDToken() else {
            status = .failure("Phiên đăng nhập hết hạn. Đăng nhập lại giúp mình.")
            return
        }

        status = .working("Đang đẩy dữ liệu lên…")
        do {
            let payload = BackupPayload.snapshot(from: context, deviceName: UIDevice.current.name)
            let json = String(data: try encoder.encode(payload), encoding: .utf8) ?? "{}"
            let stamp = try await firestore.set(path: documentPath(uid: session.uid),
                                                json: json, idToken: token)
            markSynced(stamp)
            remoteUpdatedAt = stamp
            status = .success("Đã lưu \(payload.summary) lên đám mây.")
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    // MARK: - Tải về

    func pull(context: ModelContext, auth: AuthService) async {
        guard let session = auth.firebaseSession else {
            status = .failure("Chưa đăng nhập bằng tài khoản thật.")
            return
        }
        guard let token = await auth.currentIDToken() else {
            status = .failure("Phiên đăng nhập hết hạn. Đăng nhập lại giúp mình.")
            return
        }

        status = .working("Đang tải dữ liệu về…")
        do {
            guard let document = try await firestore.get(path: documentPath(uid: session.uid),
                                                         idToken: token) else {
                status = .failure("Trên đám mây chưa có bản sao lưu nào cho tài khoản này.")
                return
            }
            guard let data = document.json.data(using: .utf8) else {
                status = .failure("Bản sao lưu bị hỏng.")
                return
            }

            let payload = try decoder.decode(BackupPayload.self, from: data)
            guard payload.version <= BackupPayload.currentVersion else {
                status = .failure("Bản sao lưu được tạo bởi phiên bản app mới hơn. Cập nhật app rồi thử lại.")
                return
            }

            try payload.restore(into: context)
            markSynced(document.updatedAt)
            remoteUpdatedAt = document.updatedAt
            WidgetRefresh.reload()
            status = .success("Đã khôi phục \(payload.summary).")
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    // MARK: - Tự quyết định chiều

    /// Gọi ngay sau khi đăng nhập: máy trống thì kéo về, máy đã có dữ liệu thì đẩy lên.
    func syncAfterSignIn(context: ModelContext, auth: AuthService) async {
        guard let session = auth.firebaseSession,
              let token = await auth.currentIDToken() else { return }

        status = .working("Đang kiểm tra bản sao lưu…")
        do {
            let remote = try await firestore.get(path: documentPath(uid: session.uid), idToken: token)
            let localSessions = (try? context.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 0
            let localMeals = (try? context.fetchCount(FetchDescriptor<MealEntry>())) ?? 0
            let localIsEmpty = localSessions == 0 && localMeals == 0

            if remote != nil && localIsEmpty {
                await pull(context: context, auth: auth)
            } else if remote == nil {
                await push(context: context, auth: auth)
            } else {
                remoteUpdatedAt = remote?.updatedAt
                status = .idle
            }
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    func checkRemote(auth: AuthService) async {
        guard let session = auth.firebaseSession,
              let token = await auth.currentIDToken() else { return }
        remoteUpdatedAt = try? await firestore.get(path: documentPath(uid: session.uid),
                                                   idToken: token)?.updatedAt
    }

    private func markSynced(_ date: Date) {
        lastSyncedAt = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.lastSyncKey)
    }
}
