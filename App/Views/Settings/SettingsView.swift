import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var location: LocationActivityService
    @EnvironmentObject private var theme: ThemeState
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var sync: SyncService

    @Query private var profiles: [UserProfile]
    @Query private var exercises: [Exercise]
    @Query private var foods: [FoodItem]

    @State private var showConditions = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var confirmPull = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let user = auth.currentUser {
                        HStack(spacing: 12) {
                            Image(systemName: user.provider == .guest ? "person.crop.circle" : "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(IconPalette.insight)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(user.displayName).font(.body.weight(.medium))
                                Text(user.provider == .guest
                                     ? "Chưa đăng nhập — dữ liệu chỉ nằm trên máy này"
                                     : "Đăng nhập bằng \(user.provider.label)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button(role: .destructive) {
                            auth.signOut()
                            dismiss()
                        } label: {
                            Label(user.provider == .guest ? "Đăng nhập tài khoản" : "Đăng xuất",
                                  systemImage: user.provider == .guest ? "person.badge.plus" : "rectangle.portrait.and.arrow.right")
                        }
                    }
                } header: {
                    Text("Tài khoản")
                } footer: {
                    Text("Đăng xuất chỉ xoá phiên đăng nhập; dữ liệu tập luyện và ăn uống trên máy vẫn giữ nguyên.")
                        .font(.caption2)
                }

                if let p = profile {
                    Section("Hồ sơ") {
                        TextField("Tên", text: Binding(get: { p.name }, set: { p.name = $0; save() }))
                        Picker("Giới tính", selection: Binding(get: { p.sex }, set: { p.sex = $0; save() })) {
                            ForEach(BiologicalSex.allCases) { Text($0.label).tag($0) }
                        }
                        DatePicker("Ngày sinh", selection: Binding(get: { p.birthDate }, set: { p.birthDate = $0; save() }),
                                   displayedComponents: .date)
                        HStack {
                            Text("Chiều cao (cm)")
                            Spacer()
                            TextField("170", value: Binding(get: { p.heightCm }, set: { p.heightCm = $0; save() }), format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }

                    Section {
                        Picker("Mức vận động", selection: Binding(get: { p.activityLevel }, set: { p.activityLevel = $0; save() })) {
                            ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                        }
                        ForEach(GoalType.allCases) { goal in
                            Button {
                                var current = p.goals
                                if let idx = current.firstIndex(of: goal) {
                                    // Luôn giữ lại ít nhất một mục tiêu.
                                    if current.count > 1 { current.remove(at: idx) }
                                } else {
                                    current.append(goal)
                                }
                                p.goals = current
                                save()
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: goal.systemImage)
                                        .foregroundStyle(p.goals.contains(goal) ? Color.brand : Color.secondary)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(goal.label)
                                        Text(goal.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    if p.goals.contains(goal) {
                                        Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Điều chỉnh calo")
                                Spacer()
                                Text("\(Int(p.calorieOffsetRatio * 100))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { p.calorieOffsetRatio },
                                    set: { p.customCalorieOffset = $0; save() }
                                ),
                                in: -0.35...0.25, step: 0.01
                            )
                            Button("Về mặc định của mục tiêu") {
                                p.customCalorieOffset = nil
                                save()
                            }
                            .font(.caption)
                        }
                    } header: {
                        Text("Mục tiêu")
                    } footer: {
                        Text(p.isRecomposition
                             ? "Chọn cả giảm mỡ lẫn tăng cơ nghĩa là tái cấu trúc cơ thể: app giữ calo quanh mức duy trì (hụt nhẹ 4%) và đẩy đạm lên 2.6 g/kg khối nạc. Tiến độ chậm hơn nhưng bền."
                             : "Thâm hụt 15-20% TDEE là mức bền vững cho giảm mỡ. Sâu hơn 25% làm tăng nguy cơ mất cơ và rối loạn nội tiết. Chọn được nhiều mục tiêu cùng lúc.")
                            .font(.caption2)
                    }

                    Section("Sức khoẻ") {
                        Button {
                            showConditions = true
                        } label: {
                            HStack {
                                Text("Bệnh nền")
                                Spacer()
                                Text(p.conditions.isEmpty ? "Chưa khai báo" : "\(p.conditions.count) mục")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Toggle("Nền đen, chữ trắng (tương phản cao)", isOn: $theme.isHighContrast)
                        .tint(IconPalette.training)
                } header: {
                    Text("Giao diện")
                } footer: {
                    Text("Nền đen, chữ trắng có độ tương phản cao. Thanh tiến độ hoàn thành và công tắc đang bật giữ màu xanh lá để dễ nhận biết. Giao diện dịu hơn trong phòng gym thiếu sáng và tiết kiệm pin trên màn OLED.")
                        .font(.caption2)
                }

                Section {
                    if !FirebaseConfig.isConfigured {
                        Label("Chưa cấu hình Firebase", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(IconPalette.energy)
                        Text("Điền Project ID và Web API Key vào FirebaseConfig.swift để bật sao lưu đám mây. Hướng dẫn lấy hai giá trị này nằm ngay trong file đó.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !auth.canSync {
                        Text("Đang dùng ở chế độ chỉ lưu trên máy. Đăng nhập bằng Apple, Google hoặc Facebook để bật sao lưu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Lần đồng bộ gần nhất")
                            Spacer()
                            Text(sync.lastSyncedAt.map { Fmt.dayMonth.string(from: $0) + " " + $0.formatted(date: .omitted, time: .shortened) } ?? "Chưa lần nào")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }

                        Button {
                            Task { await sync.push(context: context, auth: auth) }
                        } label: {
                            Label("Đẩy dữ liệu lên đám mây", systemImage: "arrow.up.circle")
                        }

                        Button {
                            confirmPull = true
                        } label: {
                            Label("Tải dữ liệu từ đám mây về", systemImage: "arrow.down.circle")
                        }
                    }

                    switch sync.status {
                    case .working(let message):
                        HStack { ProgressView(); Text(message).font(.footnote) }
                    case .success(let message):
                        Text(message).font(.caption).foregroundStyle(IconPalette.training)
                    case .failure(let message):
                        Text(message).font(.caption).foregroundStyle(AlertPalette.over)
                    case .idle:
                        EmptyView()
                    }
                } header: {
                    Text("Sao lưu & đồng bộ")
                } footer: {
                    Text("Dữ liệu được lưu thành một bản sao lưu trên Firebase Firestore, chỉ tài khoản của bạn đọc được. App tự đẩy bản mới mỗi khi bạn rời khỏi app. Đây là sao lưu ghi đè, không phải hợp nhất — dùng hai máy cùng lúc thì máy đẩy sau sẽ ghi đè máy đẩy trước.")
                        .font(.caption2)
                }

                Section("Vị trí & thời tiết") {
                    HStack {
                        Text("Quyền vị trí")
                        Spacer()
                        Text(locationStatusText).foregroundStyle(.secondary).font(.footnote)
                    }
                    if location.authorizationStatus == .notDetermined {
                        Button("Cấp quyền vị trí") { location.requestPermission() }
                    }
                    Button("Làm mới thời tiết") {
                        Task {
                            await weatherStore.refresh(
                                context: context,
                                coordinate: location.currentLocation?.coordinate,
                                force: true
                            )
                        }
                    }
                    if let w = weatherStore.today {
                        Text("Hiện tại: \(Int(w.meanTempC))°C · UV \(String(format: "%.1f", w.uvIndexMax)) · độ ẩm \(Int(w.humidityPercent))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Thư viện dữ liệu") {
                    HStack {
                        Text("Bài tập")
                        Spacer()
                        Text("\(exercises.count)").foregroundStyle(.secondary).monospacedDigit()
                    }
                    HStack {
                        Text("Món ăn")
                        Spacer()
                        Text("\(foods.count)").foregroundStyle(.secondary).monospacedDigit()
                    }
                    Button {
                        Task { await catalog.syncExercises(context: context) }
                    } label: {
                        if case .syncing(let m) = catalog.exerciseSync {
                            HStack { ProgressView(); Text(m).font(.footnote) }
                        } else {
                            Label("Tải thêm bài tập từ wger.de", systemImage: "arrow.down.circle")
                        }
                    }
                    switch catalog.exerciseSync {
                    case .success(let m): Text(m).font(.caption).foregroundStyle(Color.brandGreen)
                    case .failure(let m): Text(m).font(.caption).foregroundStyle(Color.brandRed)
                    default: EmptyView()
                    }
                }

                Section {
                    Button {
                        didCompleteOnboarding = false
                        dismiss()
                    } label: {
                        Label("Thiết lập lại từ đầu", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Chạy lại luồng hỏi từng bước như lần đầu mở app. Dữ liệu tập luyện và ăn uống đã ghi vẫn giữ nguyên.")
                        .font(.caption2)
                }

                Section {
                    Text(ConditionAdvisor.disclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Miễn trừ trách nhiệm y tế", systemImage: "exclamationmark.shield")
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Xong") { dismiss() } }
            }
            .sheet(isPresented: $showConditions) { ConditionsView() }
            .alert("Ghi đè dữ liệu trên máy?", isPresented: $confirmPull) {
                Button("Tải về và ghi đè", role: .destructive) {
                    Task { await sync.pull(context: context, auth: auth) }
                }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Toàn bộ buổi tập, bữa ăn và số đo trên máy này sẽ bị thay bằng bản trên đám mây. Không hoàn tác được.")
            }
        }
    }

    private var locationStatusText: String {
        switch location.authorizationStatus {
        case .notDetermined: return "Chưa hỏi"
        case .denied: return "Đã từ chối"
        case .restricted: return "Bị hạn chế"
        case .authorizedAlways: return "Luôn cho phép"
        case .authorizedWhenInUse: return "Khi dùng app"
        @unknown default: return "Không rõ"
        }
    }

    private func save() { try? context.save() }
}
