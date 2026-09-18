import Foundation

enum AnatomyLayer: String, CaseIterable, Identifiable {
    case superficial, intermediate, deep
    var id: String { rawValue }
    var label: String {
        switch self { case .superficial: return "Nông"; case .intermediate: return "Trung gian"; case .deep: return "Sâu" }
    }
}

/// Original bilateral diagrams informed by OpenStax 11.3–11.6.
/// Deeper views are selected dissection windows, not a single uniform anatomical plane.
enum MuscleAnatomyGeometry {
    enum Fiber { case longitudinal, diagonal, transverse, fan }
    struct Region {
        var muscle: AnatomicalMuscle
        var path: String
        var anchor: (Double, Double)
        var fiber: Fiber
        init(_ muscle: AnatomicalMuscle, _ path: String, _ x: Double, _ y: Double, _ fiber: Fiber = .longitudinal) {
            self.muscle = muscle; self.path = path; self.anchor = (x, y); self.fiber = fiber
        }
    }
    static func regions(rear: Bool, layer: AnatomyLayer) -> [Region] {
        switch (rear, layer) {
        case (false, .superficial): return front
        case (true, .superficial): return back
        case (false, .intermediate): return frontMiddle
        case (true, .intermediate): return backMiddle
        case (false, .deep): return frontDeep
        case (true, .deep): return backDeep
        }
    }
    static func location(of muscle: AnatomicalMuscle) -> (rear: Bool, layer: AnatomyLayer) {
        for layer in AnatomyLayer.allCases {
            for rear in [false, true] where regions(rear: rear, layer: layer).contains(where: { $0.muscle == muscle }) {
                return (rear, layer)
            }
        }
        preconditionFailure("Missing geometry for \(muscle)")
    }

    static let front: [Region] = [
        .init(.sternocleidomastoid, "M 104 53 L 109 55 L 117 79 L 108 74 Z", 110, 67),
        .init(.middleDeltoid, "M 68 80 Q 51 81 49 101 Q 48 114 53 126 Q 57 116 63 108 Q 68 96 70 87 Z", 57, 100),
        .init(.anteriorDeltoid, "M 72 82 Q 78 82 83 86 Q 82 95 76 108 Q 65 120 58 128 Q 61 111 67 96 Z", 71, 101),
        .init(.upperPectoralisMajor, "M 84 84 Q 101 79 118 89 L 118 101 Q 99 98 79 104 Q 80 93 84 84 Z", 101, 91, .fan),
        .init(.middlePectoralisMajor, "M 79 104 Q 99 98 118 101 L 118 119 Q 98 123 77 116 Q 77 109 79 104 Z", 100, 111, .fan),
        .init(.lowerPectoralisMajor, "M 77 116 Q 98 123 118 119 L 118 126 Q 112 133 102 135 Q 89 134 79 121 Z", 100, 127, .fan),
        .init(.serratusAnterior, "M 80 124 L 94 135 L 82 141 L 94 146 L 83 152 L 96 157 L 87 165 L 80 149 Z", 87, 145, .diagonal),
        .init(.longHeadBiceps, "M 59 129 L 66 123 Q 65 143 55 160 L 52 157 Q 51 144 59 129 Z", 58, 143),
        .init(.shortHeadBiceps, "M 66 123 L 75 116 Q 74 145 58 164 L 55 160 Q 65 143 66 123 Z", 67, 141),
        .init(.brachioradialis, "M 49 160 L 51 173 L 38 205 L 32 220 L 33 201 Z", 41, 183),
        .init(.flexorCarpiRadialis, "M 48 180 L 50 186 L 39 218 L 35 233 L 33 226 Z", 41, 206),
        .init(.palmarisLongus, "M 52 185 L 53 195 L 43 222 L 39 238 L 37 232 Z", 45, 214),
        .init(.flexorCarpiUlnaris, "M 56 176 L 59 181 L 49 207 L 44 224 L 41 235 L 40 230 L 47 204 Z", 52, 195),
        .init(.externalOblique, "M 86 165 Q 93 161 98 159 L 99 199 Q 104 220 114 237 Q 101 230 92 219 Q 86 204 86 190 Z", 94, 193, .diagonal),
        .init(.rectusAbdominis, "M 102 138 Q 110 138 118 135 L 118 157 Q 109 160 101 157 Z", 110, 148),
        .init(.rectusAbdominis, "M 101 163 Q 109 161 118 163 L 118 180 Q 110 181 102 180 Z", 110, 172),
        .init(.rectusAbdominis, "M 103 184 Q 110 183 118 185 L 118 204 Q 112 204 105 202 Z", 111, 195),
        .init(.rectusAbdominis, "M 106 208 Q 112 207 118 209 L 118 236 Q 113 229 111 224 Z", 112, 219),
        .init(.tensorFasciaeLatae, "M 83 232 L 91 239 L 85 271 L 77 280 L 77 253 Z", 82, 250),
        .init(.adductorLongus, "M 116 252 L 119 281 L 108 317 L 101 287 Z", 111, 281),
        .init(.gracilis, "M 119 289 L 115 320 L 105 358 L 103 350 L 111 316 Z", 111, 322),
        .init(.vastusLateralis, "M 82 274 Q 87 269 90 273 Q 87 295 88 319 Q 90 339 91 349 L 84 349 Q 77 333 77 309 Q 76 289 82 274 Z", 83, 309),
        .init(.rectusFemoris, "M 92 250 Q 100 254 102 265 Q 105 290 98 325 L 92 345 Q 88 336 87 320 Q 87 282 92 250 Z", 96, 290),
        .init(.vastusMedialis, "M 106 310 Q 105 329 103 345 Q 101 361 93 366 Q 91 360 92 351 Q 98 329 106 310 Z", 99, 347),
        .init(.sartorius, "M 90 236 L 96 245 L 103 287 L 107 332 L 101 352 L 100 326 L 97 288 Z", 100, 307, .diagonal),
        .init(.tibialisAnterior, "M 89 381 L 97 389 L 94 430 L 89 470 L 86 463 L 87 428 Z", 92, 421),
        .init(.fibularisLongus, "M 79 379 L 83 389 L 79 427 L 81 446 L 76 434 Q 72 405 79 379 Z", 78, 407),
        .init(.extensorDigitorumLongus, "M 84 387 L 87 398 L 85 434 L 86 461 L 82 448 L 81 425 Z", 84, 425)
    ]
    static let back: [Region] = [
        .init(.upperTrapezius, "M 109 58 L 118 59 L 118 91 Q 99 88 80 90 Q 94 82 104 74 Z", 107, 78, .diagonal),
        .init(.middleTrapezius, "M 80 90 Q 99 88 118 91 L 118 119 Q 105 115 89 113 Q 84 102 80 90 Z", 105, 103, .transverse),
        .init(.lowerTrapezius, "M 89 113 Q 105 115 118 119 L 118 150 Q 108 139 96 126 Z", 107, 129, .diagonal),
        .init(.middleDeltoid, "M 68 81 Q 52 82 50 104 L 55 124 L 64 111 L 70 89 Z", 58, 99),
        .init(.posteriorDeltoid, "M 73 83 L 83 91 L 78 107 L 59 126 L 65 109 Z", 72, 102),
        .init(.teresMajor, "M 81 112 L 97 134 L 93 141 L 78 127 Z", 87, 129, .diagonal),
        .init(.latissimusDorsi, "M 79 132 Q 86 137 94 145 L 118 159 L 117 232 Q 107 225 95 216 Q 84 199 80 179 Q 77 158 79 132 Z", 98, 178, .diagonal),
        .init(.longHeadTriceps, "M 65 123 L 76 115 Q 76 139 58 167 L 55 161 Q 66 141 65 123 Z", 68, 139),
        .init(.lateralHeadTriceps, "M 58 129 L 65 123 Q 66 141 55 161 L 50 162 Z", 58, 141),
        .init(.extensorCarpiRadialisLongus, "M 48 165 L 51 178 L 38 205 L 34 229 L 30 221 L 35 193 Z", 40, 194),
        .init(.extensorDigitorum, "M 52 179 L 54 188 L 44 215 L 39 237 L 35 231 L 39 211 Z", 44, 210),
        .init(.extensorCarpiUlnaris, "M 56 178 L 59 182 L 48 211 L 42 235 L 40 230 L 44 212 Z", 51, 200),
        .init(.gluteusMedius, "M 94 217 L 114 232 L 96 247 L 80 249 Q 83 229 94 217 Z", 96, 235, .fan),
        .init(.gluteusMaximus, "M 80 252 Q 90 249 100 247 L 118 239 L 118 279 Q 110 290 97 290 Q 86 288 80 275 Q 77 263 80 252 Z", 102, 265, .diagonal),
        .init(.bicepsFemoris, "M 80 283 L 94 293 L 91 329 L 88 366 L 81 354 Q 73 316 80 283 Z", 84, 324),
        .init(.semitendinosus, "M 98 293 L 117 286 L 109 325 L 97 365 L 92 370 L 95 331 Z", 103, 319),
        .init(.gastrocnemius, "M 82 378 Q 70 394 78 431 L 87 447 L 90 410 Z", 81, 408),
        .init(.gastrocnemius, "M 95 378 Q 107 393 99 428 L 89 448 L 92 408 Z", 98, 408)
    ]
    static let frontMiddle: [Region] = [
        .init(.pectoralisMinor, "M 79 95 L 96 107 L 114 141 L 96 131 Z", 95, 117, .fan),
        .init(.externalIntercostals, "M 88 121 L 103 127 L 107 132 L 89 128 Z M 88 132 L 106 138 L 110 143 L 89 139 Z M 89 143 L 109 149 L 111 154 L 90 150 Z", 98, 139, .diagonal),
        .init(.brachialis, "M 62 121 L 75 119 L 67 146 L 57 168 L 50 160 Z", 62, 143),
        .init(.coracobrachialis, "M 75 105 Q 71 113 69 127 L 63 151 L 60 145 L 65 119 Z", 68, 128),
        .init(.flexorDigitorumSuperficialis, "M 51 173 Q 55 180 53 191 L 43 216 L 39 234 L 35 229 L 40 207 Z", 46, 200, .longitudinal),
        .init(.internalOblique, "M 86 149 L 118 168 L 118 237 L 94 219 L 85 188 Z", 101, 191, .diagonal),
        .init(.vastusIntermedius, "M 86 257 L 99 260 L 104 296 L 98 349 L 88 350 L 80 301 Z", 92, 306),
        .init(.adductorMagnus, "M 108 248 L 118 262 L 113 308 L 105 346 L 102 306 L 103 277 Z", 110, 286)
    ]
    static let backMiddle: [Region] = [
        .init(.medialHeadTriceps, "M 58 130 L 72 121 Q 71 145 58 167 L 50 162 Z", 61, 146),
        .init(.spleniusCapitis, "M 103 53 L 109 52 L 118 94 L 112 98 L 105 75 Z", 109, 71, .diagonal),
        .init(.levatorScapulae, "M 103 72 L 109 76 L 101 104 L 94 101 Z", 101, 87, .diagonal),
        .init(.rhomboidMinor, "M 118 97 L 118 107 L 99 105 L 96 96 Z", 108, 101, .diagonal),
        .init(.rhomboidMajor, "M 118 112 L 118 144 L 99 127 L 97 109 Z", 109, 122, .diagonal),
        .init(.supraspinatus, "M 79 88 L 94 91 L 95 98 L 75 103 Z", 85, 96, .transverse),
        .init(.infraspinatus, "M 78 107 L 94 104 L 98 132 L 86 127 L 76 115 Z", 87, 116, .fan),
        .init(.teresMinor, "M 76 118 L 96 136 L 95 143 L 76 127 Z", 85, 132, .diagonal),
        .init(.erectorSpinae, "M 106 142 L 113 150 L 114 234 L 100 219 L 100 176 Z", 107, 188),
        .init(.gluteusMinimus, "M 96 222 L 115 237 L 98 255 L 82 250 Z", 99, 241, .fan),
        .init(.piriformis, "M 117 256 L 117 268 L 81 267 L 86 258 Z", 101, 262, .transverse),
        .init(.semimembranosus, "M 110 282 L 117 289 L 108 332 L 99 365 L 92 354 L 97 309 Z", 105, 319),
        .init(.soleus, "M 81 382 Q 71 409 82 450 L 88 470 L 98 441 Q 105 405 95 382 L 88 390 Z", 88, 424)
    ]
    static let frontDeep: [Region] = [
        .init(.subclavius, "M 84 84 Q 98 82 113 88 L 112 93 Q 98 88 86 90 Z", 99, 87, .transverse),
        .init(.subscapularis, "M 78 90 L 99 99 L 94 133 L 80 122 L 74 108 Z", 86, 109, .fan),
        .init(.internalIntercostals, "M 101 115 L 115 119 L 115 124 L 100 121 Z M 99 126 L 115 131 L 115 136 L 99 132 Z M 98 138 L 114 143 L 114 148 L 98 144 Z", 106, 134, .diagonal),
        .init(.transversusAbdominis, "M 85 145 L 118 151 L 118 229 L 95 217 L 85 189 Z", 103, 186, .transverse),
        .init(.iliopsoas, "M 108 180 L 115 181 L 114 251 L 107 281 L 95 255 L 88 232 L 99 225 L 104 240 Z", 106, 243),
        .init(.adductorBrevis, "M 110 244 L 118 254 L 113 281 L 104 295 L 103 279 Z", 111, 270, .diagonal)
    ]
    static let backDeep: [Region] = [
        .init(.multifidus, "M 115 130 L 119 135 L 119 241 L 110 226 L 109 174 Z", 115, 192, .diagonal),
        .init(.quadratusLumborum, "M 98 178 L 109 175 L 110 224 L 101 231 L 96 215 Z", 103, 205),
        .init(.popliteus, "M 81 367 L 99 371 L 95 384 L 83 380 Z", 90, 375, .diagonal),
        .init(.flexorDigitorumLongus, "M 81 388 L 87 391 L 86 427 L 84 456 L 79 442 L 78 414 Z", 83, 421),
        .init(.tibialisPosterior, "M 88 387 L 96 391 L 95 423 L 91 457 L 85 448 L 86 420 Z", 90, 420),
        .init(.flexorHallucisLongus, "M 97 388 L 102 397 L 101 426 L 96 459 L 93 449 L 96 415 Z", 98, 422)
    ]
}
