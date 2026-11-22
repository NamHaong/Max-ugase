import Foundation
import Darwin

/// Tốc độ mạng đo bằng bộ đếm byte của giao diện (en0 = Wi-Fi, pdp_ip0 = di động).
final class NetworkMonitor {
    struct Speed { var wifiDown = 0.0, wifiUp = 0.0, cellDown = 0.0, cellUp = 0.0 } // bytes/s
    struct Totals { var wifiIn: UInt64 = 0, wifiOut: UInt64 = 0, cellIn: UInt64 = 0, cellOut: UInt64 = 0 }

    private var last: (Totals, Date)?

    static func totals() -> Totals {
        var t = Totals()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return t }
        defer { freeifaddrs(ifaddr) }
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let addr = p.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
                  let data = p.pointee.ifa_data else { continue }
            let name = String(cString: p.pointee.ifa_name)
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            if name == "en0" { t.wifiIn += UInt64(d.ifi_ibytes); t.wifiOut += UInt64(d.ifi_obytes) }
            if name.hasPrefix("pdp_ip") { t.cellIn += UInt64(d.ifi_ibytes); t.cellOut += UInt64(d.ifi_obytes) }
        }
        return t
    }

    func speed() -> Speed {
        let now = Date(), t = Self.totals()
        defer { last = (t, now) }
        guard let (lt, ld) = last else { return Speed() }
        let dt = now.timeIntervalSince(ld)
        guard dt > 0 else { return Speed() }
        func rate(_ a: UInt64, _ b: UInt64) -> Double { a >= b ? Double(a - b) / dt : 0 }
        return Speed(wifiDown: rate(t.wifiIn, lt.wifiIn), wifiUp: rate(t.wifiOut, lt.wifiOut),
                     cellDown: rate(t.cellIn, lt.cellIn), cellUp: rate(t.cellOut, lt.cellOut))
    }
}

func formatSpeed(_ bps: Double) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .binary) + "/s"
}
