import SwiftUI
import SwiftData

/// Khai báo bệnh nền và xem khuyến nghị tập tương ứng.
struct ConditionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]
    @State private var selected: Set<HealthConditionKind> = []

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(ConditionAdvisor.disclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Lưu ý quan trọng", systemImage: "exclamationmark.shield.fill")
                        .foregroundStyle(Color.brandRed)
                }

                Section("Bệnh nền của bạn") {
                    ForEach(HealthConditionKind.allCases.filter { $0 != .none }) { c in
                        Button {
                            if selected.contains(c) { selected.remove(c) } else { selected.insert(c) }
                            persist()
                        } label: {
                            HStack {
                                Text(c.label)
                                Spacer()
                                if selected.contains(c) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(ConditionAdvisor.allGuidance(for: Array(selected))) { g in
                    Section {
                        Text(g.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        DisclosureGroup("Nên làm") {
                            ForEach(g.recommended, id: \.self) { r in
                                Label(r, systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                        .tint(Color.brandGreen)

                        DisclosureGroup("Cần tránh / thận trọng") {
                            ForEach(g.cautions, id: \.self) { c in
                                Label(c, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                            }
                        }
                        .tint(Color.brandRed)

                        if !g.preferredMuscles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nhóm cơ nên ưu tiên").font(.caption.weight(.semibold))
                                FlowChips(items: g.preferredMuscles.map(\.label))
                            }
                        }
                    } header: {
                        Text(g.condition.label)
                    } footer: {
                        Text("Nguồn: " + g.sourceLabel).font(.caption2)
                    }
                }
            }
            .navigationTitle("Bệnh nền")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Xong") { dismiss() } }
            }
            .onAppear {
                selected = Set(profile?.conditions ?? [])
            }
        }
    }

    private func persist() {
        profile?.conditions = Array(selected)
        try? context.save()
    }
}
