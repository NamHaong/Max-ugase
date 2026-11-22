import SwiftUI

struct InfoView: View {
    @Environment(SystemStore.self) private var s

    var body: some View {
        let d = s.device
        NavigationStack {
            List {
                Section("Thiết bị") {
                    RowKV("Tên", d.name)
                    RowKV("Mã model", d.modelIdentifier)
                    RowKV("iOS", "\(d.osVersion) (\(d.osBuild))")
                    RowKV("Thời gian bật máy", formatDuration(d.uptime))
                    RowKV("Khởi động lúc", d.bootTime.formatted(date: .abbreviated, time: .shortened))
                }
                Section("Vi xử lý & bộ nhớ") {
                    RowKV("Nhân vật lý / logic", "\(d.cpuCoresPhysical) / \(d.cpuCoresLogical)")
                    RowKV("RAM", d.ramTotal.bytesString)
                    RowKV("RAM nén", s.memory.compressed.bytesString)
                    RowKV("RAM wired", s.memory.wired.bytesString)
                    RowKV("RAM trống", s.memory.free.bytesString)
                    RowKV("RAM app này", s.memory.appFootprint.bytesString)
                    RowKV("L1d / L2 cache", "\(d.l1d / 1024) KB / \(d.l2 / 1024) KB")
                    RowKV("Kích thước trang", "\(d.pageSize) B")
                }
                Section("Lưu trữ") {
                    RowKV("Tổng", s.storage.total.bytesString)
                    RowKV("Đã dùng", s.storage.used.bytesString)
                    RowKV("Trống", s.storage.freeRaw.bytesString)
                }
                Section("Màn hình") {
                    RowKV("Kích thước (pt)", "\(Int(d.screenPoints.width)) × \(Int(d.screenPoints.height)) @\(Int(d.screenScale))x")
                    RowKV("Tần số quét tối đa", "\(d.maxRefreshRate) Hz")
                    RowKV("Độ sáng", "\(Int(d.brightness * 100))%")
                }
                Section("Nhân hệ điều hành") { Text(d.kernel).font(.caption2).textSelection(.enabled) }
            }
            .navigationTitle("Thiết bị")
        }
    }
}
