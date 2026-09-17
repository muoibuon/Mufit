import SwiftUI
import SwiftData

@main
struct MufitApp: App {

    let container: ModelContainer
    @StateObject private var catalog = CatalogStore()
    @StateObject private var weather = WeatherStore()
    @StateObject private var location = LocationActivityService()
    @StateObject private var theme = ThemeState.shared
    @StateObject private var router = AppRouter()
    @StateObject private var auth = AuthService()
    @StateObject private var sync = SyncService()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    init() {
        // Store nằm trong App Group để widget đọc được cùng dữ liệu.
        container = SharedStore.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .id(theme.isHighContrast)
                .preferredColorScheme(theme.forcedColorScheme)
                .environmentObject(theme)
                .environmentObject(router)
                .environmentObject(auth)
                .environmentObject(sync)
                .environmentObject(catalog)
                .environmentObject(weather)
                .environmentObject(location)
                .fullScreenCover(isPresented: Binding(
                    get: { !auth.isSignedIn || !didCompleteOnboarding },
                    set: { _ in }
                )) {
                    LaunchGateView(needsOnboarding: !didCompleteOnboarding) {
                        didCompleteOnboarding = true
                    }
                    .environmentObject(auth)
                .environmentObject(sync)
                    .environmentObject(theme)
                    .animation(.easeInOut(duration: 0.25), value: auth.isSignedIn)
                }
                .onOpenURL { router.handle($0) }
                .onChange(of: auth.firebaseSession?.uid) { _, uid in
                    // Vừa nối được tài khoản: kéo bản sao lưu về nếu máy này còn trống.
                    guard uid != nil else { return }
                    Task { await sync.syncAfterSignIn(context: container.mainContext, auth: auth) }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Đẩy bản mới nhất mỗi khi rời app, để đổi máy là có ngay.
                    guard phase == .background, auth.canSync else { return }
                    Task { await sync.push(context: container.mainContext, auth: auth) }
                }
                .task {
                    let context = container.mainContext
                    catalog.seedIfNeeded(context: context)
                    weather.loadCached(context: context)
                    await weather.refresh(context: context, coordinate: location.currentLocation?.coordinate)
                }
        }
        .modelContainer(container)
    }
}
