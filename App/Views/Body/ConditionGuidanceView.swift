import SwiftUI
import SwiftData

/// Chỉ đọc: xem đầy đủ khuyến nghị tập luyện cho các bệnh nền đã khai báo.
/// Tách khỏi màn khai báo để bấm "Xem chi tiết gợi ý" không nhảy vào chỗ chỉnh sửa.
struct ConditionGuidanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var showEditor = false

    private var conditions: [HealthConditionKind] {
        profiles.first?.conditions ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(ConditionAdvisor.disclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Lưu ý quan trọng", systemImage: "exclamationmark.shield.fill")
                        .foregroundStyle(AlertPalette.over)
                }

                if conditions.isEmpty {
                    Section {
                        EmptyStateView(
                            systemImage: "cross.case",
                            title: "Chưa khai báo bệnh nền",
                            message: "Khai báo để app điều chỉnh gợi ý bài tập và cảnh báo an toàn theo tình trạng của bạn."
                        )
                    }
                }

                ForEach(ConditionAdvisor.allGuidance(for: conditions)) { g in
                    Section {
                        Text(g.summary)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Nên làm", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.brandGreen)
                            ForEach(g.recommended, id: \.self) { r in
                                bullet(r)
                            }
                        }
                        .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Cần tránh / thận trọng", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AlertPalette.over)
                            ForEach(g.cautions, id: \.self) { c in
                                bullet(c)
                            }
                        }
                        .padding(.vertical, 2)

                        if !g.preferredMuscles.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nhóm cơ nên ưu tiên")
                                    .font(.caption.weight(.semibold))
                                FlowChips(items: g.preferredMuscles.map(\.label))
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text(g.condition.label)
                    } footer: {
                        Text("Nguồn: " + g.sourceLabel).font(.caption2)
                    }
                }

                Section {
                    Button {
                        showEditor = true
                    } label: {
                        Label(conditions.isEmpty ? "Khai báo bệnh nền" : "Chỉnh sửa bệnh nền",
                              systemImage: "square.and.pencil")
                    }
                }
            }
            .navigationTitle("Gợi ý theo bệnh nền")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Xong") { dismiss() } }
            }
            .sheet(isPresented: $showEditor) { ConditionsView() }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
