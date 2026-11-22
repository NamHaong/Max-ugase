import Foundation
import UIKit

struct DeviceDetails {
    var name = UIDevice.current.name
    var modelIdentifier = sysctlString("hw.machine")
    var osVersion = UIDevice.current.systemVersion
    var osBuild = sysctlString("kern.osversion")
    var cpuCoresPhysical = sysctlInt("hw.physicalcpu")
    var cpuCoresLogical = sysctlInt("hw.logicalcpu")
    var ramTotal = ProcessInfo.processInfo.physicalMemory
    var cpuFamily = sysctlInt("hw.cpufamily")
    var pageSize = sysctlInt("hw.pagesize")
    var l1d = sysctlInt("hw.l1dcachesize")
    var l2 = sysctlInt("hw.l2cachesize")
    var kernel = sysctlString("kern.version")
    var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }
    var bootTime: Date { Date(timeIntervalSinceNow: -uptime) }
    var screenPoints: CGSize { UIScreen.main.bounds.size }
    var screenScale: CGFloat { UIScreen.main.scale }
    var maxRefreshRate: Int { UIScreen.main.maximumFramesPerSecond }
    var brightness: CGFloat { UIScreen.main.brightness }
}

func sysctlString(_ name: String) -> String {
    var size = 0
    sysctlbyname(name, nil, &size, nil, 0)
    guard size > 0 else { return "?" }
    var buf = [CChar](repeating: 0, count: size)
    sysctlbyname(name, &buf, &size, nil, 0)
    return String(cString: buf)
}

func sysctlInt(_ name: String) -> Int {
    var v: Int64 = 0
    var size = MemoryLayout<Int64>.size
    if sysctlbyname(name, &v, &size, nil, 0) != 0 {
        var v32: Int32 = 0
        var s32 = MemoryLayout<Int32>.size
        sysctlbyname(name, &v32, &s32, nil, 0)
        return Int(v32)
    }
    return Int(v)
}

func formatDuration(_ t: TimeInterval) -> String {
    let d = Int(t) / 86400, h = Int(t) % 86400 / 3600, m = Int(t) % 3600 / 60
    return d > 0 ? "\(d)n \(h)g \(m)p" : "\(h)g \(m)p"
}
