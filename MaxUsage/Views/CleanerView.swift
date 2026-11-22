import SwiftUI

struct CleanerView: View {
    @Environment(SystemStore.self) private var s
    @State private var cacheSize: Int64 = 0
    @State private var log: [String] = []
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                Section("Giải phóng RAM") {
                    Button {
                        killHeavy()
                    } label: {
                        Label("Dừng các app nền nặng nhất (top 5)", systemImage: "bolt.horizontal.circle")
                    }
                    Text("Buộc dừng 5 ứng dụng người dùng đang chiếm nhiều RAM nhất (không đụng tiến trình hệ thống). Cần entitlement bỏ sandbox.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Bộ nhớ đệm") {
                    RowKV("Cache của app này", cacheSize.bytesString)
                    Button { clearOwnCache() } label: { Label("Xóa cache & thư mục tạm của app", systemImage: "trash") }
                    Button { clearSystemCaches() } label: { Label("Xóa cache của các app khác (/var/mobile/Containers)", systemImage: "trash.slash") }
                    Text("Mục thứ hai chỉ chạy được khi app đã bỏ sandbox. Xóa thư mục Library/Caches và tmp, không đụng dữ liệu người dùng.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Dung lượng") {
                    RowKV("Trống", s.storage.freeRaw.bytesString)
                    RowKV("Có thể thu hồi", Int64(max(0, s.storage.freeImportant - s.storage.freeRaw)).bytesString)
                }
                if !log.isEmpty {
                    Section("Nhật ký") { ForEach(log, id: \.self) { Text($0).font(.caption) } }
                }
            }
            .navigationTitle("Dọn dẹp")
            .onAppear(perform: refreshCache)
        }
    }

    private func refreshCache() {
        let dirs = [FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
                    URL(fileURLWithPath: NSTemporaryDirectory())].compactMap { $0 }
        cacheSize = dirs.reduce(0) { $0 + StorageMonitor.folderSize($1) }
    }

    private func clearOwnCache() {
        let before = cacheSize
        let dirs = [FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
                    URL(fileURLWithPath: NSTemporaryDirectory())].compactMap { $0 }
        for d in dirs { removeContents(of: d) }
        URLCache.shared.removeAllCachedResponses()
        refreshCache()
        log.insert("Đã xóa \((before - cacheSize).bytesString) cache của app.", at: 0)
    }

    private func clearSystemCaches() {
        let roots = ["/var/mobile/Containers/Data/Application", "/var/mobile/Library/Caches"]
        var freed: Int64 = 0
        let fm = FileManager.default
        for root in roots {
            if root.hasSuffix("Application") {
                guard let apps = try? fm.contentsOfDirectory(atPath: root) else { log.insert("Không truy cập được \(root) (còn sandbox).", at: 0); continue }
                for a in apps {
                    for sub in ["Library/Caches", "tmp"] {
                        let u = URL(fileURLWithPath: "\(root)/\(a)/\(sub)")
                        freed += StorageMonitor.folderSize(u)
                        removeContents(of: u)
                    }
                }
            } else {
                let u = URL(fileURLWithPath: root)
                freed += StorageMonitor.folderSize(u)
                removeContents(of: u)
            }
        }
        log.insert("Đã xóa khoảng \(freed.bytesString) cache hệ thống/app khác.", at: 0)
    }

    private func removeContents(of dir: URL) {
        let fm = FileManager.default
        for item in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: item)
        }
    }

    private func killHeavy() {
        let me = Int(getpid())
        let targets = s.processes.filter { $0.isUserApp && !$0.isCritical && $0.pid != me }
            .sorted { $0.resident > $1.resident }.prefix(5)
        guard !targets.isEmpty else { log.insert("Không tìm thấy app nền nào (cần quyền đọc tiến trình).", at: 0); return }
        var freed: UInt64 = 0
        for p in targets where ProcessMonitor.kill(p.pid) { freed += p.resident; log.insert("Đã dừng \(p.name) (\(p.resident.bytesString))", at: 0) }
        log.insert("Giải phóng khoảng \(freed.bytesString) RAM.", at: 0)
    }
}
