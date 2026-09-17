import SwiftUI
import SwiftData

struct MuscleAtlasExplorer: View {
    var profile: UserProfile
    var measurement: BodyMeasurement?
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [WorkoutSession]
    @State private var sex: BiologicalSex = .male
    @State private var rear = false
    @State private var layer: AnatomyLayer = .superficial
    @State private var zoom = 1.0
    @State private var search = ""
    @State private var selected: AnatomicalMuscle?

    private var filtered: [AnatomicalMuscle] {
        AnatomicalMuscle.allCases.filter {
            search.isEmpty || $0.label.localizedStandardContains(search) || $0.latin.localizedStandardContains(search)
                || $0.info.region.localizedStandardContains(search)
        }
    }
    private var areas: [String] { Array(Set(filtered.map { $0.info.region })).sorted() }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Calendar.current.startOfDay(for: .now), by: 60)) { _ in
                let stats = AnatomicalTrainingTracker.stats(records: AnatomicalTrainingTracker.records(from: sessions))
                let trained = Set(stats.filter(\.trained).map(\.muscle))
                List {
                    if search.isEmpty {
                        Section("Khám phá mô hình") {
                            Picker("Mô hình", selection: $sex) { ForEach(BiologicalSex.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                            Picker("Góc nhìn", selection: $rear) {
                                Text("Trước").tag(false); Text("Sau").tag(true)
                            }.pickerStyle(.segmented)
                            Picker("Lớp cơ", selection: $layer) { ForEach(AnatomyLayer.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                            HStack {
                                Image(systemName: "minus.magnifyingglass")
                                Slider(value: $zoom, in: 1...2, step: 0.25).accessibilityLabel("Phóng to mô hình")
                                Text(zoom.formatted(.number.precision(.fractionLength(2))) + "×").font(.caption.monospacedDigit())
                            }
                            ScrollView(.horizontal) {
                                MuscleAnatomyView(sex: sex, rear: rear, layer: layer, trained: trained) { selected = $0 }
                                    .frame(width: 280 * zoom, height: 607 * zoom)
                                    .padding(6)
                            }
                            Text("Kéo ngang khi phóng to. Chạm cơ hoặc tìm theo tên Việt/Latin trong danh mục bên dưới.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if filtered.isEmpty { ContentUnavailableView.search(text: search) }
                    ForEach(areas, id: \.self) { area in
                        Section(area) {
                            ForEach(filtered.filter { $0.info.region == area }) { muscle in
                                Button { selected = muscle } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(muscle.label).foregroundStyle(.primary)
                                            Text(muscle.latin).font(.caption).foregroundStyle(.secondary)
                                            let place = MuscleAnatomyGeometry.location(of: muscle)
                                            Text("\(place.rear ? "Mặt sau" : "Mặt trước") · lớp \(place.layer.label.lowercased())")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if trained.contains(muscle) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brandGreen) }
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Section("Tài liệu giải phẫu") {
                        Text("OpenStax · Anatomy & Physiology 2e. Sơ đồ vector được tự vẽ, tham khảo vị trí và lớp cơ trong các chương dưới đây. Các vùng lớp sâu là cửa sổ bóc tách chọn lọc.")
                            .font(.caption)
                        ForEach(AnatomicalMuscle.AnatomySource.allCases) { source in
                            Link(source.chapter, destination: source.url).font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Tra cứu \(AnatomicalMuscle.allCases.count) cấu trúc")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Tên Việt, Latin hoặc vùng cơ")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
            .sheet(item: $selected) { MuscleDetailView(muscle: $0, profile: profile, measurement: measurement) }
        }
        .onAppear { sex = profile.sex }
    }
}
