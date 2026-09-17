import SwiftUI

/// Màn đăng nhập, hiện trước luồng cá nhân hoá khi chưa có tài khoản.
struct SignInView: View {
    @EnvironmentObject private var auth: AuthService

    /// Đã có nhà cung cấp nào cấu hình xong chưa — dùng để chọn câu chú thích cho đúng.
    private var hasConfiguredProvider: Bool {
        AuthConfig.isGoogleConfigured || AuthConfig.isFacebookConfigured
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 12) {
                Image("AppLogoMark")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 64)
                    .foregroundStyle(.primary)

                Text("Mufit")
                    .font(.system(size: 40, weight: .heavy))

                Text("Đăng nhập để hồ sơ, lịch tập và nhật ký ăn uống gắn với tài khoản của bạn.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                // Sign in with Apple cần entitlement chỉ cấp cho tài khoản trả phí,
                // nên bản cài qua AltStore không hiện nút này.
                #if !SIDELOAD
                providerButton(.apple, background: .white, foreground: .black) {
                    AppleLogo(size: 22)
                }
                #endif
                providerButton(.google, background: .white, foreground: .black) {
                    GoogleLogo(size: 22)
                }
                providerButton(.facebook,
                               background: Color(red: 0.094, green: 0.467, blue: 0.949),
                               foreground: .white) {
                    FacebookLogo(size: 22, style: .onBrandBackground)
                }

                if let message = auth.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AlertPalette.over)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    auth.signInAsGuest()
                } label: {
                    Text("Dùng thử không cần tài khoản")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.secondary)

                Text(hasConfiguredProvider
                     ? "Đăng nhập để dữ liệu gắn với tài khoản và sao lưu lên đám mây."
                     : "Chưa cấu hình khoá ứng dụng nên các nút đăng nhập chưa hoạt động. Dữ liệu hiện được lưu trên máy này.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .preferredColorScheme(ThemeState.shared.forcedColorScheme)
        .overlay {
            if auth.isWorking {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func providerButton<Logo: View>(_ provider: AuthProvider,
                                            background: Color,
                                            foreground: Color,
                                            @ViewBuilder logo: () -> Logo) -> some View {
        Button {
            Task { await auth.signIn(with: provider) }
        } label: {
            HStack(spacing: 10) {
                logo()
                Text("Tiếp tục với \(provider.label)")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(foreground)
        }
        .disabled(auth.isWorking)
    }
}
