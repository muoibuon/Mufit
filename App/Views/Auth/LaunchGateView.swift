import SwiftUI

/// Cổng vào app: đăng nhập trước, rồi tới cá nhân hoá.
///
/// Gộp hai bước vào **một** `fullScreenCover` duy nhất. Gắn hai cover lên cùng một
/// view thì SwiftUI chỉ nhận một cái — bước thứ hai sẽ không bao giờ hiện ra.
struct LaunchGateView: View {
    @EnvironmentObject private var auth: AuthService

    var needsOnboarding: Bool
    var onFinishOnboarding: () -> Void

    var body: some View {
        if !auth.isSignedIn {
            SignInView()
                .transition(.opacity)
        } else if needsOnboarding {
            OnboardingView(onFinish: onFinishOnboarding)
                .transition(.opacity)
        } else {
            Color.appBackground.ignoresSafeArea()
        }
    }
}
