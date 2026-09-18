import SwiftUI
import SwiftData

/// Hiện ra khi app phát hiện bạn đã di chuyển đáng kể: hỏi có tắm nắng không, bao lâu.
struct SunExposureSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var location: LocationActivityService

    @State private var wasOutdoor = true
    @State private var minutes: Double = 15
    @State private var exposure: Double = 25

    private var uv: Double { weatherStore.today?.uvIndexMax ?? 5 }

    private var estimatedIU: Double {
        wasOutdoor ? VitaminDAdvisor.estimateIU(minutes: minutes, uvIndex: uv, skinExposurePercent: exposure) : 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("App thấy bạn đã di chuyển \(Int(location.distanceTodayMeters)) m hôm nay. Bạn có ở ngoài trời không?")
                        .font(.subheadline)
                    Toggle("Có ra ngoài trời", isOn: $wasOutdoor)
                        .tint(IconPalette.training)
                }

                if wasOutdoor {
                    Section("Thời gian dưới nắng") {
                        HStack {
                            Text("\(Int(minutes)) phút").monospacedDigit()
                            Slider(value: $minutes, in: 0...120, step: 5)
                        }
                    }

                    Section("Diện tích da hở") {
                        Picker("Da hở", selection: $exposure) {
                            Text("Chỉ mặt và bàn tay (~10%)").tag(10.0)
                            Text("Tay ngắn (~25%)").tag(25.0)
                            Text("Tay và chân hở (~40%)").tag(40.0)
                            Text("Áo ba lỗ, quần short (~60%)").tag(60.0)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section("Ước lượng") {
                        HStack {
                            Text("Chỉ số UV hôm nay")
                            Spacer()
                            Text(String(format: "%.1f", uv)).monospacedDigit().foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Vitamin D tổng hợp")
                            Spacer()
                            Text("≈ \(Int(estimatedIU)) IU").monospacedDigit().foregroundStyle(Color.brandWarm)
                        }
                        Text(VitaminDAdvisor.advise(
                            logs: [SunExposureLog(minutes: minutes, uvIndex: uv, skinExposurePercent: exposure)],
                            uvIndexToday: uv
                        ).message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("""
                    Ước lượng dựa trên mối liên hệ giữa UV-B, diện tích da hở và thời lượng (Holick, NEJM 2007). \
                    Đây là con số tham khảo, không thay thế xét nghiệm 25(OH)D. Tránh phơi nắng tới mức đỏ da.
                    """)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Hôm nay có tắm nắng?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Bỏ qua") {
                        location.markSunPromptAnswered()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") {
                        context.insert(SunExposureLog(
                            minutes: wasOutdoor ? minutes : 0,
                            uvIndex: uv,
                            skinExposurePercent: exposure,
                            wasOutdoor: wasOutdoor
                        ))
                        try? context.save()
                        location.markSunPromptAnswered()
                        dismiss()
                    }
                }
            }
        }
    }
}
