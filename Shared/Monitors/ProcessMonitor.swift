import Foundation

struct ProcInfo: Identifiable {
    var id: Int { pid }
    let pid: Int
    let name: String
    let path: String
    let resident: UInt64
    let virtual: UInt64
    let threads: Int
    var cpuPercent: Double = 0

    /// Tiến trình hệ thống không nên kill.
    var isCritical: Bool {
        pid <= 1 || ["launchd", "kernel_task", "backboardd", "SpringBoard", "runningboardd", "configd",
                     "mediaserverd", "locationd", "securityd", "powerd", "thermalmonitord", "UserEventAgent"].contains(name)
    }
    var isUserApp: Bool { path.contains("/Applications/") || path.contains("/containers/Bundle/Application/") }
}

final class ProcessMonitor {
    private var lastCPU: [Int: UInt64] = [:]
    private var lastTime: Date?

    /// Đọc danh sách tiến trình, tính %CPU từng tiến trình giữa 2 lần gọi.
    func read() -> [ProcInfo] {
        let raw = MUListProcesses()
        let now = Date()
        let dt = lastTime.map { now.timeIntervalSince($0) } ?? 0
        var newCPU: [Int: UInt64] = [:]
        var result: [ProcInfo] = []

        for d in raw {
            guard (d["hasInfo"] as? NSNumber)?.boolValue == true,
                  let pid = (d["pid"] as? NSNumber)?.intValue else { continue }
            let cpuNs = (d["cpuTime"] as? NSNumber)?.uint64Value ?? 0
            newCPU[pid] = cpuNs
            var p = ProcInfo(pid: pid,
                             name: d["name"] as? String ?? "?",
                             path: d["path"] as? String ?? "",
                             resident: (d["resident"] as? NSNumber)?.uint64Value ?? 0,
                             virtual: (d["virtual"] as? NSNumber)?.uint64Value ?? 0,
                             threads: (d["threads"] as? NSNumber)?.intValue ?? 0)
            if dt > 0, let prev = lastCPU[pid], cpuNs >= prev {
                p.cpuPercent = Double(cpuNs - prev) / (dt * 1_000_000_000) * 100
            }
            result.append(p)
        }
        lastCPU = newCPU
        lastTime = now
        return result
    }

    @discardableResult
    static func kill(_ pid: Int, force: Bool = true) -> Bool {
        MUKillProcess(Int32(pid), force ? 9 : 15) == 0
    }
}
