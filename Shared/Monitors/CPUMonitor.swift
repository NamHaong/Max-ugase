import Foundation
import Darwin

/// % CPU toàn hệ thống và từng nhân (so sánh 2 lần đọc liên tiếp).
final class CPUMonitor {
    private var previous: [[UInt32]] = []

    struct Reading {
        var total: Double      // 0...100
        var cores: [Double]    // 0...100 mỗi nhân
    }

    func read() -> Reading {
        var coreCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &coreCount, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info else { return Reading(total: 0, cores: []) }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        var current: [[UInt32]] = []
        for i in 0..<Int(coreCount) {
            let base = Int(CPU_STATE_MAX) * i
            current.append([
                UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            ])
        }
        defer { previous = current }
        guard previous.count == current.count else { return Reading(total: 0, cores: Array(repeating: 0, count: current.count)) }

        var cores: [Double] = []
        var busyAll = 0.0, totalAll = 0.0
        for (c, p) in zip(current, previous) {
            let user = Double(c[0] &- p[0]), sys = Double(c[1] &- p[1])
            let idle = Double(c[2] &- p[2]), nice = Double(c[3] &- p[3])
            let total = user + sys + idle + nice
            let busy = user + sys + nice
            cores.append(total > 0 ? busy / total * 100 : 0)
            busyAll += busy; totalAll += total
        }
        return Reading(total: totalAll > 0 ? busyAll / totalAll * 100 : 0, cores: cores)
    }
}
