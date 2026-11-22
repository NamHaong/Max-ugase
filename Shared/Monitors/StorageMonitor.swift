import Foundation

struct StorageInfo {
    var total: Int64 = 0
    var freeRaw: Int64 = 0          // trống thật sự
    var freeImportant: Int64 = 0    // trống + có thể thu hồi (iOS tự dọn)
    var used: Int64 { total - freeRaw }
    var usedPercent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }
}

enum StorageMonitor {
    static func read() -> StorageInfo {
        var s = StorageInfo()
        let url = URL(fileURLWithPath: "/var")
        if let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey,
                                                     .volumeAvailableCapacityForImportantUsageKey]) {
            s.total = Int64(v.volumeTotalCapacity ?? 0)
            s.freeRaw = Int64(v.volumeAvailableCapacity ?? 0)
            s.freeImportant = v.volumeAvailableCapacityForImportantUsage ?? s.freeRaw
        }
        return s
    }

    /// Kích thước thư mục (đệ quy).
    static func folderSize(_ url: URL) -> Int64 {
        guard let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
                                                      options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        for case let f as URL in en {
            total += Int64((try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        return total
    }
}

extension Int64 {
    var bytesString: String { ByteCountFormatter.string(fromByteCount: self, countStyle: .binary) }
}
extension UInt64 {
    var bytesString: String { Int64(clamping: self).bytesString }
}
