import Foundation
import UIKit

struct BatteryInfo {
    var level: Double = 0                 // 0...100
    var state: UIDevice.BatteryState = .unknown
    var lowPower = false

    // Từ IORegistry (AppleSmartBattery) – có thể nil nếu iOS chặn
    var temperatureC: Double?
    var voltageV: Double?
    var amperageA: Double?                // âm = đang xả, dương = đang sạc
    var systemPowerInW: Double?           // công suất vào hệ thống từ củ sạc (PowerTelemetryData)
    var batteryPowerW: Double?            // công suất vào/ra pin (PowerTelemetryData), + = sạc
    var cycleCount: Int?
    var designCapacity: Int?              // mAh
    var maxCapacity: Int?                 // mAh (raw)
    var currentCapacity: Int?             // mAh
    var adapterWatts: Int?
    var ioRegistryReadable = false

    /// Công suất đo trực tiếp (W). + = sạc, - = xả.
    var powerW: Double? {
        if let v = voltageV, let a = amperageA, abs(a) > 0.001 { return v * a }
        return batteryPowerW
    }
    var healthPercent: Double? {
        guard let d = designCapacity, let m = maxCapacity, d > 0 else { return nil }
        return Double(m) / Double(d) * 100
    }
    var isCharging: Bool { state == .charging || state == .full }
}

enum BatteryMonitor {
    /// Số nguyên có dấu; xử lý trường hợp giá trị 32-bit âm bị đọc thành số dương lớn.
    private static func signed(_ n: NSNumber) -> Double {
        let v = n.int64Value
        if v > 2_147_483_647 && v < 4_294_967_296 { return Double(v - 4_294_967_296) }
        return Double(v)
    }

    static func read() -> BatteryInfo {
        var b = BatteryInfo()
        let dev = UIDevice.current
        dev.isBatteryMonitoringEnabled = true
        b.level = Double(max(0, dev.batteryLevel)) * 100
        b.state = dev.batteryState
        b.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

        guard let d = MUReadIORegistry("AppleSmartBattery") else { return b }
        b.ioRegistryReadable = true
        func num(_ k: String, in dict: [AnyHashable: Any]? = nil) -> NSNumber? { ((dict ?? d)[k]) as? NSNumber }

        if let t = num("Temperature") { b.temperatureC = t.doubleValue / 100 }
        if let v = num("Voltage") ?? num("AppleRawBatteryVoltage") { b.voltageV = v.doubleValue / 1000 }

        // Dòng: thử các khóa theo thứ tự, lấy giá trị khác 0 đầu tiên
        let telemetry = d["PowerTelemetryData"] as? [AnyHashable: Any]
        let charger = d["ChargerData"] as? [AnyHashable: Any]
        var amps: [Double] = []
        if let n = num("InstantAmperage") { amps.append(signed(n)) }
        if let n = num("Amperage") { amps.append(signed(n)) }
        if let a = amps.first(where: { abs($0) > 0.5 }) { b.amperageA = a / 1000 }
        else if let c = num("ChargingCurrent", in: charger), c.doubleValue > 0, b.state == .charging { b.amperageA = c.doubleValue / 1000 }
        else if !amps.isEmpty { b.amperageA = 0 }

        if let p = num("SystemPowerIn", in: telemetry) { b.systemPowerInW = p.doubleValue / 1000 }
        if let p = num("BatteryPower", in: telemetry) { b.batteryPowerW = signed(p) / 1000 }

        b.cycleCount = num("CycleCount")?.intValue
        b.designCapacity = num("DesignCapacity")?.intValue
        b.maxCapacity = (num("AppleRawMaxCapacity") ?? num("NominalChargeCapacity"))?.intValue
        b.currentCapacity = num("AppleRawCurrentCapacity")?.intValue
        if let ad = d["AdapterDetails"] as? [AnyHashable: Any], let w = num("Watts", in: ad) { b.adapterWatts = w.intValue }
        return b
    }
}
