import Foundation

struct GPUInfo {
    var utilization: Double?       // %
    var rendererUtilization: Double?
    var tilerUtilization: Double?
    var inUseMemory: Int64?        // bytes
    var allocatedMemory: Int64?
}

enum GPUMonitor {
    static func read() -> GPUInfo {
        var g = GPUInfo()
        guard let d = MUReadIORegistry("IOAccelerator"),
              let p = d["PerformanceStatistics"] as? [String: Any] else { return g }
        func num(_ k: String) -> Double? { (p[k] as? NSNumber)?.doubleValue }
        g.utilization = num("Device Utilization %")
        g.rendererUtilization = num("Renderer Utilization %")
        g.tilerUtilization = num("Tiler Utilization %")
        g.inUseMemory = (p["In use system memory"] as? NSNumber)?.int64Value
        g.allocatedMemory = (p["Alloc system memory"] as? NSNumber)?.int64Value
        return g
    }
}
