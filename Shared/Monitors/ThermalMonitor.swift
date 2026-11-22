import Foundation

struct ThermalSensor: Identifiable {
    var id: String { name }
    let name: String
    let celsius: Double

    /// Nhóm hiển thị thân thiện suy từ tên cảm biến.
    var category: String {
        let n = name.lowercased()
        if n.contains("gas gauge") || n.contains("battery") { return "Pin" }
        if n.contains("tdev") || n.contains("pmgr") || n.contains("soc") || n.contains("cpu") || n.contains("pacc") || n.contains("eacc") { return "CPU / SoC" }
        if n.contains("gpu") { return "GPU" }
        if n.contains("nand") || n.contains("ans") { return "Bộ nhớ NAND" }
        if n.contains("charger") || n.contains("tcal") || n.contains("tg0") { return "Sạc / Khác" }
        return "Khác"
    }
}

enum ThermalMonitor {
    static var state: ProcessInfo.ThermalState { ProcessInfo.processInfo.thermalState }

    static var stateText: String {
        switch state {
        case .nominal: return "Bình thường"
        case .fair: return "Hơi ấm"
        case .serious: return "Nóng"
        case .critical: return "Quá nóng"
        @unknown default: return "Không rõ"
        }
    }

    /// Cần entitlement HID (TrollStore). Nếu không có quyền sẽ trả về rỗng.
    static func sensors() -> [ThermalSensor] {
        MUReadThermalSensors()
            .compactMap { d -> ThermalSensor? in
                guard let name = d["name"] as? String, let v = (d["value"] as? NSNumber)?.doubleValue else { return nil }
                return ThermalSensor(name: name, celsius: v)
            }
            .sorted { $0.name < $1.name }
    }

    static func average(of category: String, in s: [ThermalSensor]) -> Double? {
        let v = s.filter { $0.category == category }.map(\.celsius)
        return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }

    /// Nhiệt độ trung bình toàn máy: trung bình mọi cảm biến HID hợp lệ; nếu không có thì dùng nhiệt độ pin.
    static func overallAverage(sensors: [ThermalSensor], battery: Double?) -> (value: Double, source: String)? {
        let v = sensors.map(\.celsius).filter { $0 > 5 && $0 < 90 }
        if !v.isEmpty { return (v.reduce(0, +) / Double(v.count), "\(v.count) cảm biến") }
        if let b = battery { return (b, "cảm biến pin") }
        return nil
    }
}
