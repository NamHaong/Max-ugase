import Foundation

/// Ước tính tốc độ sạc/xả từ lịch sử % pin khi iOS không cho đọc dòng điện thật.
final class ChargeEstimator {
    private var points: [(time: Date, level: Double)] = []
    private var wasCharging: Bool?

    /// Dung lượng pin danh định (mAh) theo model, dùng để quy đổi %/giờ ra W. Chỉ là ước lượng.
    static let capacityTable: [String: Double] = [
        "iPhone10,1": 1821, "iPhone10,4": 1821, "iPhone10,2": 2691, "iPhone10,5": 2691, "iPhone10,3": 2716, "iPhone10,6": 2716,
        "iPhone11,2": 2658, "iPhone11,4": 3174, "iPhone11,6": 3174, "iPhone11,8": 2942,
        "iPhone12,1": 3110, "iPhone12,3": 3046, "iPhone12,5": 3969, "iPhone12,8": 1821,
        "iPhone13,1": 2227, "iPhone13,2": 2815, "iPhone13,3": 2815, "iPhone13,4": 3687,
        "iPhone14,2": 3095, "iPhone14,3": 4352, "iPhone14,4": 2406, "iPhone14,5": 3240, "iPhone14,6": 2018,
        "iPhone14,7": 3279, "iPhone14,8": 4325, "iPhone15,2": 3200, "iPhone15,3": 4323,
        "iPhone15,4": 3349, "iPhone15,5": 4383, "iPhone16,1": 3274, "iPhone16,2": 4441,
        "iPhone17,1": 3582, "iPhone17,2": 4685, "iPhone17,3": 3561, "iPhone17,4": 4674, "iPhone17,5": 3279
    ]
    static let nominalVoltage = 3.85

    var capacityMAh: Double?
    private(set) var ratePctPerHour: Double?   // + sạc, - xả

    func update(level: Double, charging: Bool, designCapacity: Int?) {
        capacityMAh = designCapacity.map(Double.init) ?? Self.capacityTable[sysctlString("hw.machine")]
        if wasCharging != charging { points.removeAll(); ratePctPerHour = nil }
        wasCharging = charging
        let now = Date()
        if points.last?.level != level { points.append((now, level)) }
        points.removeAll { now.timeIntervalSince($0.time) > 20 * 60 }
        if points.count >= 2, let f = points.first, let l = points.last, l.time.timeIntervalSince(f.time) > 30 {
            ratePctPerHour = (l.level - f.level) / (l.time.timeIntervalSince(f.time) / 3600)
        }
    }

    /// Công suất ước tính (W), + = sạc, - = xả.
    var estimatedPowerW: Double? {
        guard let r = ratePctPerHour, let c = capacityMAh else { return nil }
        return r / 100 * c / 1000 * Self.nominalVoltage
    }
    var estimatedCurrentMA: Double? {
        guard let r = ratePctPerHour, let c = capacityMAh else { return nil }
        return r / 100 * c
    }
}
