import SwiftUI
import SwiftData

struct WeeklyMuscleMapView: View {
    var profile: UserProfile
    var measurement: BodyMeasurement?
    @Query private var sessions: [WorkoutSession]
    @Environment(\.scenePhase) private var scenePhase
    @State private var figureSex: BiologicalSex = .male
    @State private var rear = false
    @State private var layer: AnatomyLayer = .superficial
    @State private var selectedMuscle: AnatomicalMuscle?
    @State private var showAtlas = false
    @State private var refresh = Date.now

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: .now), by: 60)) { _ in
            let now = max(Date.now, refresh)
            let stats = AnatomicalTrainingTracker.stats(records: AnatomicalTrainingTracker.records(from: sessions), now: now)
            let groups = WeeklyMuscleTracker.stats(records: WeeklyMuscleTracker.records(from: sessions), now: now)
            let trained = Set(stats.filter(\.trained).map(\.muscle))
            let related = Set(groups.filter(\.trained).map(\.muscle))
            let week = WeeklyMuscleTracker.week(containing: now)
            Card(title: "Bản đồ cơ tuần này", systemImage: "figure.strengthtraining.traditional") {
                Text("\(AnatomicalMuscle.selectableCases.count) vùng cơ · nam & nữ")
                    .font(.subheadline.weight(.semibold))
                Text("\(week.start.formatted(.dateTime.day().month())) – \(week.end.addingTimeInterval(-1).formatted(.dateTime.day().month())) · \(trained.count) cấu trúc có bài liên quan")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Chạm vào vùng cơ để xem tên, tần suất và ghi chú")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                MuscleAnatomyView(sex: figureSex, rear: rear, layer: layer, trained: trained, relatedGroups: related) {
                    selectedMuscle = $0
                }
                .frame(width: 240)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.appCardElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                }
                Text("Tùy chọn hiển thị")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Picker("Mô hình cơ thể", selection: $figureSex) {
                    ForEach(BiologicalSex.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
                Picker("Góc nhìn", selection: $rear) {
                    Text("Mặt trước").tag(false)
                    Text("Mặt sau").tag(true)
                }.pickerStyle(.segmented)
                Picker("Lớp giải phẫu", selection: $layer) {
                    ForEach(AnatomyLayer.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
                Button { showAtlas = true } label: {
                    Label("Phóng to & tra cứu tên cơ", systemImage: "arrow.up.left.and.arrow.down.right")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                VStack(alignment: .leading, spacing: 5) {
                    Label("Xanh: có bài liên quan (ước tính)", systemImage: "circle.fill").foregroundStyle(Color(red: 0.08, green: 0.57, blue: 0.39))
                    Label("Vàng: chỉ biết nhóm cơ đã tập", systemImage: "circle.lefthalf.filled").foregroundStyle(.orange)
                    Label("Hồng: chưa có dữ liệu ánh xạ", systemImage: "circle").foregroundStyle(.secondary)
                }.font(.caption)
                Text("Màu xanh giữ hết Chủ nhật và làm mới 00:00 thứ Hai theo giờ thiết bị. Ghi chú và lịch sử không bị xóa. Màu xanh không xác nhận mức kích thích hoặc khả năng hồi phục của từng cơ.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Minh họa chọn lọc theo OpenStax 11.3–11.6, gồm ngực lớn trên/giữa/dưới, ba bó cơ thang, hai đầu cơ nhị đầu, ba đầu cơ tam đầu và các cơ khác. Đây là các vùng hoặc đầu của cùng một cơ, không phải những cơ riêng. Lớp trung gian/sâu là các cửa sổ bóc tách; không phân biệt trái/phải trong dữ liệu tập.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onAppear { figureSex = profile.sex; refresh = .now }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh = .now } }
        .sheet(item: $selectedMuscle) { MuscleDetailView(muscle: $0, profile: profile, measurement: measurement) }
        .sheet(isPresented: $showAtlas) { MuscleAtlasExplorer(profile: profile, measurement: measurement) }
    }
}

struct MuscleDetailView: View {
    var muscle: AnatomicalMuscle
    var profile: UserProfile
    var measurement: BodyMeasurement?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var note = ""
    @State private var originalNote = ""
    @State private var error: String?
    @State private var confirmDiscard = false

    private func examples(direct: Bool) -> [Exercise] {
        exercises.filter { exercise in
            let targets = AnatomicalTrainingTracker.targets(slug: exercise.slug, isCustom: exercise.isCustom)
            return direct ? targets.direct.contains(muscle) : targets.assisting.contains(muscle)
        }
    }

    private var evidence: (String, URL)? {
        let source: (String, String)
        switch muscle.parentMuscle {
        case .pectoralisMajor: source = ("Nghiên cứu góc ghế và ba vùng ngực", "https://pubmed.ncbi.nlm.nih.gov/33049982/")
        case .trapezius: source = ("Nghiên cứu ba bó cơ thang", "https://pubmed.ncbi.nlm.nih.gov/12774999/")
        case .bicepsBrachii: source = ("Nghiên cứu biến thể curl và đầu dài nhị đầu", "https://pubmed.ncbi.nlm.nih.gov/24150552/")
        case .tricepsBrachii: source = ("Nghiên cứu vị trí tay và các đầu tam đầu", "https://pubmed.ncbi.nlm.nih.gov/35819335/")
        default: return nil
        }
        return (source.0, URL(string: source.1)!)
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Calendar.current.startOfDay(for: .now), by: 60)) { timeline in
                let now = Date.now
                let stats = AnatomicalTrainingTracker.stats(records: AnatomicalTrainingTracker.records(from: sessions), now: now)
                let stat = stats.first { $0.muscle == muscle } ?? .init(muscle: muscle)
                Form {
                    Section {
                        Label(stat.trained ? "Có bài tập liên quan trong tuần" : "Chưa đủ dữ liệu cho cơ này",
                              systemImage: stat.trained ? "circle.fill" : "circle")
                            .foregroundStyle(stat.trained ? Color(red: 0.08, green: 0.57, blue: 0.39) : .secondary)
                        LabeledContent("Số ngày / số buổi", value: "\(stat.days) ngày / \(stat.sessions) buổi")
                        LabeledContent("Hiệp cơ chính", value: "\(stat.directSets)")
                        LabeledContent("Hiệp tham gia hỗ trợ", value: "\(stat.assistingSets)")
                        if let last = stat.lastTrained {
                            LabeledContent("Lần gần nhất", value: last.formatted(date: .abbreviated, time: .shortened))
                        }
                    } header: { Text("Tần suất tuần này") } footer: {
                        Text("Màu xanh là ước tính từ loại bài tập đã ghi, không phải phép đo hoạt động của cơ. Một ngày có nhiều buổi chỉ tính là một ngày tập. Chỉ tính hiệp có số lần thực hiện > 0 trong buổi đã hoàn thành; không tính khởi động. Cơ hỗ trợ cũng được tô xanh, nhưng chưa thể suy ra mức kích thích bằng cơ chính.")
                    }
                    if !examples(direct: true).isEmpty || !examples(direct: false).isEmpty {
                        Section {
                            if !examples(direct: true).isEmpty {
                                LabeledContent("Ưu tiên vùng này", value: examples(direct: true).map(\.name).joined(separator: ", "))
                            }
                            if !examples(direct: false).isEmpty {
                                LabeledContent("Tham gia hỗ trợ", value: examples(direct: false).map(\.name).joined(separator: ", "))
                            }
                        } header: {
                            Text("Bài tập liên quan trong thư viện")
                        } footer: {
                            Text("Ánh xạ theo biến thể bài tập trong thư viện. Góc, biên độ và kỹ thuật thực tế có thể thay đổi vùng được nhấn mạnh; các đầu cơ không hoạt động độc lập tuyệt đối.")
                        }
                    }
                    Section("Vị trí giải phẫu") {
                        Text(muscle.latin).font(.headline)
                        if let parent = muscle.parentMuscle {
                            Text("Một phần của \(parent.label), không phải cơ riêng.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(muscle.info.region + " · " + MuscleAnatomyGeometry.location(of: muscle).layer.label)
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 5) {
                                Text("Toàn thân").font(.caption2).foregroundStyle(.secondary)
                                MuscleAnatomyView(sex: profile.sex, rear: MuscleAnatomyGeometry.location(of: muscle).rear,
                                                  layer: MuscleAnatomyGeometry.location(of: muscle).layer,
                                                  trained: stat.trained ? [muscle] : [], highlighted: muscle) { _ in }
                                    .frame(width: 98, height: 213)
                            }
                            VStack(spacing: 5) {
                                Text("Chi tiết vùng cơ").font(.caption2).foregroundStyle(.secondary)
                                MuscleFocusView(muscle: muscle, sex: profile.sex, trained: stat.trained)
                                    .frame(height: 240)
                                    .background(Color.appCardElevated, in: RoundedRectangle(cornerRadius: 12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false).accessibilityHidden(true)
                        Text("Viền xanh dương đánh dấu cấu trúc đang xem. Các cửa sổ bóc tách minh họa được chọn riêng theo vùng, không phải một mặt phẳng giải phẫu đồng nhất.")
                            .font(.caption).foregroundStyle(.secondary)
                        Link("OpenStax Anatomy & Physiology 2e · " + muscle.info.source.chapter,
                             destination: muscle.info.source.url).font(.caption)
                        if let evidence { Link(evidence.0, destination: evidence.1).font(.caption) }
                    }
                    if let group = muscle.group {
                        let groupStats = WeeklyMuscleTracker.stats(records: WeeklyMuscleTracker.records(from: sessions), now: now)
                        let groupStat = groupStats.first { $0.muscle == group }
                        Section("Dữ liệu nhóm " + group.label.lowercased()) {
                            Text("\(groupStat?.sessions ?? 0) buổi của nhóm trong tuần. Bài chỉ có nhãn nhóm hoặc chưa được ánh xạ không xác nhận mọi cơ thành phần đều đã tập.")
                                .font(.caption)
                            let oldNote = profile.muscleNote(for: group)
                            if !oldNote.isEmpty {
                                LabeledContent("Ghi chú nhóm từ bản trước", value: oldNote)
                            }
                            if let parent = muscle.parentMuscle {
                                let parentNote = profile.muscleNote(forKey: parent.noteKey)
                                if !parentNote.isEmpty {
                                    LabeledContent("Ghi chú \(parent.label) từ bản trước", value: parentNote)
                                }
                            }
                        }
                    }
                    Section {
                        TextEditor(text: $note)
                            .frame(minHeight: 130)
                            .accessibilityLabel("Ghi chú cho vùng \(muscle.label)")
                        Text("Ví dụ: cảm giác sau tập, kỹ thuật cần nhớ, mức tạ, hướng dẫn của bác sĩ hoặc huấn luyện viên.")
                            .font(.caption).foregroundStyle(.secondary)
                    } header: { Text("Ghi chú của bạn") } footer: {
                        Text("Bấm Lưu để giữ ghi chú qua các tuần. Ghi chú được đưa vào bản sao lưu cùng hồ sơ.")
                    }
                    ForEach(MuscleTrainingGuidance.notes(muscle: muscle.group ?? .fullBody, profile: profile, measurement: measurement, now: now)) { item in
                        Section(item.title) {
                            Text(item.text).font(.subheadline)
                            if let source = item.source { sourceLink(source) }
                        }
                    }
                    Section {
                        Text("Thông tin giáo dục, không thay thế đánh giá của bác sĩ. Nếu đau ngực, ngất hoặc khó thở bất thường khi tập, dừng tập và tìm hỗ trợ y tế. Dấu xanh không dùng để đánh giá an toàn tập tiếp.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(muscle.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        if note != originalNote { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Lưu", action: save).fontWeight(.semibold) }
            }
        }
        .onAppear { note = profile.muscleNote(forKey: muscle.noteKey); originalNote = note }
        .interactiveDismissDisabled(note != originalNote)
        .confirmationDialog("Bỏ thay đổi ghi chú?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Bỏ thay đổi", role: .destructive) { dismiss() }
            Button("Tiếp tục viết", role: .cancel) { }
        }
        .alert("Chưa lưu được ghi chú", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func sourceLink(_ source: MuscleTrainingGuidance.Source) -> some View {
        Link(destination: URL(string: source.url)!) {
            Label(source.title, systemImage: "arrow.up.right.square").font(.caption)
        }
    }

    private func save() {
        let previous = profile.muscleNotesJSON
        do {
            try profile.setMuscleNote(note, forKey: muscle.noteKey)
            try context.save()
            originalNote = note
            dismiss()
        } catch {
            profile.muscleNotesJSON = previous
            self.error = "Ghi chú vẫn đang ở đây. Hãy thử lưu lại. \(error.localizedDescription)"
        }
    }
}

private struct MuscleFocusView: View {
    var muscle: AnatomicalMuscle
    var sex: BiologicalSex
    var trained: Bool

    var body: some View {
        let location = MuscleAnatomyGeometry.location(of: muscle)
        let anchor = MuscleAnatomyGeometry.regions(rear: location.rear, layer: location.layer)
            .first { $0.muscle == muscle }!.anchor
        GeometryReader { geometry in
            let width = 240.0 * 2.4
            let height = 520.0 * 2.4
            MuscleAnatomyView(sex: sex, rear: location.rear, layer: location.layer,
                              trained: trained ? [muscle] : [], highlighted: muscle) { _ in }
                .frame(width: width, height: height)
                .position(x: geometry.size.width / 2 + (120 - anchor.0) / 240 * width,
                          y: geometry.size.height / 2 + (260 - anchor.1) / 520 * height)
        }
        .clipped()
    }
}
