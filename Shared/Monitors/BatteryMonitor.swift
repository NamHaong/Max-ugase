import Foundation
import UIKit

struct BatteryInfo {
    var level: Double = 0                 // 0...100
    var state: UIDevice.BatteryState = .unknown
    var lowPower = false

    // Từ IORegistry (AppleSmartBattery) – có thể nil nếu máy không cho đọc
    var temperatureC: Double?
    var voltageV: Double?
    var amperageA: Double?                // âm = đang xả, dương = đang sạc
    var powerW: Double? { if let v = voltageV, let a = amperageA { return v * a } else { return nil } }
    var cycleCount: Int?
    var designCapacity: Int?              // mAh
    var maxCapacity: Int?                 // mAh (raw)
    var currentCapacity: Int?             // mAh
    var healthPercent: Double? {
        guard let d = designCapacity, let m = maxCapacity, d > 0 else { return nil }
        return Double(m) / Double(d) * 100
    }
    var adapterWatts: Int?
    var isCharging: Bool { state == .charging || state == .full }
}

enum BatteryMonitor {
    static func read() -> BatteryInfo {
        var b = BatteryInfo()
        let dev = UIDevice.current
        dev.isBatteryMonitoringEnabled = true
        b.level = Double(max(0, dev.batteryLevel)) * 100
        b.state = dev.batteryState
        b.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

        guard let d = MUReadIORegistry("AppleSmartBattery") else { return b }
        func int(_ k: String) -> Int? { (d[k] as? NSNumber)?.intValue }

        if let t = int("Temperature") { b.temperatureC = Double(t) / 100 }
        if let v = int("Voltage") { b.voltageV = Double(v) / 1000 }
        // Amperage là số có dấu 64-bit, có thể bị đọc thành unsigned lớn
        if let a = (d["InstantAmperage"] as? NSNumber) ?? (d["Amperage"] as? NSNumber) {
            b.amperageA = Double(Int64(bitPattern: a.uint64Value)) / 1000
        }
        b.cycleCount = int("CycleCount")
        b.designCapacity = int("DesignCapacity")
        b.maxCapacity = int("AppleRawMaxCapacity") ?? int("NominalChargeCapacity")
        b.currentCapacity = int("AppleRawCurrentCapacity")
        if let ad = d["AdapterDetails"] as? [String: Any], let w = (ad["Watts"] as? NSNumber)?.intValue { b.adapterWatts = w }
        return b
    }
}
