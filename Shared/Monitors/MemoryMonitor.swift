import Foundation
import Darwin
import os

struct MemoryInfo {
    var total: UInt64 = 0
    var free: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var appFootprint: UInt64 = 0   // RAM chính app này đang dùng
    var availableToApp: UInt64 = 0 // RAM còn cấp được trước khi bị jetsam

    var used: UInt64 { active + wired + compressed }
    var usedPercent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }
}

enum MemoryMonitor {
    static func read() -> MemoryInfo {
        var info = MemoryInfo()
        info.total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let page = UInt64(vm_kernel_page_size)
            info.free = UInt64(stats.free_count) * page
            info.active = UInt64(stats.active_count) * page
            info.inactive = UInt64(stats.inactive_count) * page
            info.wired = UInt64(stats.wire_count) * page
            info.compressed = UInt64(stats.compressor_page_count) * page
        }

        var vmInfo = task_vm_info_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr2 = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &vmCount)
            }
        }
        if kr2 == KERN_SUCCESS { info.appFootprint = vmInfo.phys_footprint }
        info.availableToApp = UInt64(max(0, os_proc_available_memory()))
        return info
    }
}
