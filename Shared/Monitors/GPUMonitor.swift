import Foundation
import Metal

struct GPUInfo {
    var utilization: Double?       // %
    var rendererUtilization: Double?
    var tilerUtilization: Double?
    var inUseMemory: Int64?        // bytes
    var allocatedMemory: Int64?
    var name: String?              // từ Metal
    var workingSetLimit: UInt64?   // bytes, từ Metal
    var utilizationReadable: Bool { utilization != nil }
}

enum GPUMonitor {
    private static let device = MTLCreateSystemDefaultDevice()

    static func read() -> GPUInfo {
        var g = GPUInfo()
        g.name = device?.name
        g.workingSetLimit = device?.recommendedMaxWorkingSetSize

        // Thử mọi service accelerator, lấy cái có PerformanceStatistics
        for service in ["IOAccelerator", "AGXAccelerator", "IOGPU"] {
            for d in MUReadIORegistryAll(service) {
                guard let p = d["PerformanceStatistics"] as? [AnyHashable: Any] else { continue }
                func num(_ k: String) -> Double? { (p[k] as? NSNumber)?.doubleValue }
                g.utilization = num("Device Utilization %") ?? num("GPU Activity(%)")
                g.rendererUtilization = num("Renderer Utilization %")
                g.tilerUtilization = num("Tiler Utilization %")
                g.inUseMemory = (p["In use system memory"] as? NSNumber)?.int64Value
                g.allocatedMemory = (p["Alloc system memory"] as? NSNumber)?.int64Value
                if g.utilization != nil { return g }
            }
        }
        return g
    }
}
