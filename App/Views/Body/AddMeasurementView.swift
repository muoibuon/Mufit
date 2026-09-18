import SwiftUI
import SwiftData

struct AddMeasurementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var date = Date()
    @State private var weight: Double = 70
    @State private var hasBodyFat = false
    @State private var bodyFat: Double = 20
    @State private var muscle: Double = 30
    @State private var water: Double = 55
    @State private var bone: Double = 3
    @State private var visceral: Double = 8
    @State private var waist: Double = 80
    @State private var hasWaist = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Cơ bản") {
                    DatePicker("Ngày đo", selection: $date, displayedComponents: .date)
                    numberRow("Cân nặng (kg)", $weight)
                }

                Section {
                    Toggle("Có số đo % mỡ", isOn: $hasBodyFat)
                        .tint(IconPalette.training)
                    if hasBodyFat {
                        numberRow("Mỡ cơ thể (%)", $bodyFat)
                        numberRow("Khối cơ xương (kg)", $muscle)
                        numberRow("Nước trong cơ thể (%)", $water)
                        numberRow("Khối xương (kg)", $bone)
                        numberRow("Mỡ nội tạng (điểm)", $visceral)
                    }
                } header: {
                    Text("Thành phần cơ thể")
                } footer: {
                    Text("Số liệu từ cân InBody, Tanita hoặc thước kẹp mỡ. Có % mỡ thì app chuyển sang công thức Katch-McArdle — chính xác hơn Mifflin-St Jeor vì tính theo khối nạc thật.")
                        .font(.caption2)
                }

                Section {
                    Toggle("Có đo vòng eo", isOn: $hasWaist)
                        .tint(IconPalette.training)
                    if hasWaist { numberRow("Vòng eo (cm)", $waist) }
                } footer: {
                    Text("Không có máy đo mỡ vẫn ước lượng được: app dùng công thức RFM từ chiều cao và vòng eo, sai số thấp hơn BMI đáng kể.")
                        .font(.caption2)
                }

                Section("Ghi chú") {
                    TextField("Vd: đo buổi sáng, lúc đói", text: $note)
                }
            }
            .navigationTitle("Nhập số đo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") {
                        context.insert(BodyMeasurement(
                            date: date,
                            weightKg: weight,
                            bodyFatPercent: hasBodyFat ? bodyFat : nil,
                            skeletalMuscleKg: hasBodyFat ? muscle : nil,
                            bodyWaterPercent: hasBodyFat ? water : nil,
                            boneMassKg: hasBodyFat ? bone : nil,
                            visceralFatRating: hasBodyFat ? visceral : nil,
                            waistCm: hasWaist ? waist : nil,
                            note: note
                        ))
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Điền sẵn từ lần đo gần nhất để nhập nhanh hơn.
                if let last = measurements.first {
                    weight = last.weightKg
                    if let bf = last.bodyFatPercent { hasBodyFat = true; bodyFat = bf }
                    if let m = last.skeletalMuscleKg { muscle = m }
                    if let w = last.bodyWaterPercent { water = w }
                    if let b = last.boneMassKg { bone = b }
                    if let v = last.visceralFatRating { visceral = v }
                    if let ws = last.waistCm { hasWaist = true; waist = ws }
                }
            }
        }
    }

    private func numberRow(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }
}
