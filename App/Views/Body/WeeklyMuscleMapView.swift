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
                Text("\(AnatomicalMuscle.allCases.count) cấu trúc cơ · nam & nữ")
                    .font(.subheadline.weight(.semibold))
                Text("\(week.start.formatted(.dateTime.day().month())) – \(week.end.addingTimeInterval(-1).formatted(.dateTime.day().month())) · \(trained.count) cấu trúc có bài liên quan")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Chạm vào vùng cơ để xem tên, tần suất và ghi chú")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                MuscleAnatomyView(sex: figureSex, rear: rear, layer: layer, trained: trained, relatedGroups: related) {
                    selectedMuscle = $0
                }
                .frame(width: 190)
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
                    Label("Xanh ✓: có bài liên quan (ước tính)", systemImage: "checkmark.circle.fill").foregroundStyle(Color.brandGreen)
                    Label("Vàng: chỉ biết nhóm cơ đã tập", systemImage: "circle.lefthalf.filled").foregroundStyle(.orange)
                    Label("Hồng: chưa có dữ liệu ánh xạ", systemImage: "circle").foregroundStyle(.secondary)
                }.font(.caption)
                Text("Tích xanh giữ hết Chủ nhật và làm mới 00:00 thứ Hai theo giờ thiết bị. Ghi chú và lịch sử không bị xóa. Dấu tích không xác nhận mức kích thích hoặc khả năng hồi phục của từng cơ.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Minh họa chọn lọc theo OpenStax 11.3–11.6, gồm cơ, bó cơ delta và một số nhóm cơ. Chọn lớp trung gian/sâu để xem các cấu trúc bị che phủ. Không phải atlas toàn bộ hơn 600 cơ, không phân biệt trái/phải trong dữ liệu tập.")
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
    @State private var note = ""
    @State private var originalNote = ""
    @State private var error: String?
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Calendar.current.startOfDay(for: .now), by: 60)) { timeline in
                let now = Date.now
                let stats = AnatomicalTrainingTracker.stats(records: AnatomicalTrainingTracker.records(from: sessions), now: now)
                let stat = stats.first { $0.muscle == muscle } ?? .init(muscle: muscle)
                Form {
                    Section {
                        Label(stat.trained ? "Có bài tập liên quan trong tuần" : "Chưa đủ dữ liệu cho cơ này",
                              systemImage: stat.trained ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(stat.trained ? Color.brandGreen : .secondary)
                        LabeledContent("Số ngày / số buổi", value: "\(stat.days) ngày / \(stat.sessions) buổi")
                        LabeledContent("Hiệp cơ chính", value: "\(stat.directSets)")
                        LabeledContent("Hiệp tham gia hỗ trợ", value: "\(stat.assistingSets)")
                        if let last = stat.lastTrained {
                            LabeledContent("Lần gần nhất", value: last.formatted(date: .abbreviated, time: .shortened))
                        }
                    } header: { Text("Tần suất tuần này") } footer: {
                        Text("Tích xanh là ước tính từ loại bài tập đã ghi, không phải phép đo hoạt động của cơ. Một ngày có nhiều buổi chỉ tính là một ngày tập. Chỉ tính hiệp có số lần thực hiện > 0 trong buổi đã hoàn thành; không tính khởi động. Cơ hỗ trợ cũng được tích xanh, nhưng chưa thể suy ra mức kích thích bằng cơ chính.")
                    }
                    Section("Vị trí giải phẫu") {
                        Text(muscle.latin).font(.headline)
                        Text(muscle.info.region + " · " + MuscleAnatomyGeometry.location(of: muscle).layer.label)
                            .font(.subheadline).foregroundStyle(.secondary)
                        MuscleAnatomyView(sex: profile.sex, rear: MuscleAnatomyGeometry.location(of: muscle).rear,
                                          layer: MuscleAnatomyGeometry.location(of: muscle).layer,
                                          trained: stat.trained ? [muscle] : [], highlighted: muscle) { _ in }
                            .frame(height: 320).frame(maxWidth: .infinity)
                            .allowsHitTesting(false).accessibilityHidden(true)
                        Text("Viền xanh dương đánh dấu cấu trúc đang xem. Các cửa sổ bóc tách minh họa được chọn riêng theo vùng, không phải một mặt phẳng giải phẫu đồng nhất.")
                            .font(.caption).foregroundStyle(.secondary)
                        Link("OpenStax Anatomy & Physiology 2e · " + muscle.info.source.chapter,
                             destination: muscle.info.source.url).font(.caption)
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
