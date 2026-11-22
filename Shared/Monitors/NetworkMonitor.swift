import Foundation
import Darwin
import Observation

/// Tốc độ mạng đo bằng bộ đếm byte của giao diện (en* = Wi-Fi, pdp_ip* = di động).
/// Bộ đếm của iOS là 32-bit nên tính hiệu có bao quanh (wrap) theo từng giao diện.
final class NetworkMonitor {
    struct Speed { var wifiDown = 0.0, wifiUp = 0.0, cellDown = 0.0, cellUp = 0.0 } // bytes/s

    private var last: ([String: (UInt32, UInt32)], Date)?
    private(set) var counters: [String: (UInt32, UInt32)] = [:]

    static func readCounters() -> [String: (UInt32, UInt32)] {
        var out: [String: (UInt32, UInt32)] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return out }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            defer { ptr = p.pointee.ifa_next }
            guard let addr = p.pointee.ifa_addr, Int32(addr.pointee.sa_family) == AF_LINK,
                  let data = p.pointee.ifa_data else { continue }
            let name = String(cString: p.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            out[name] = (d.ifi_ibytes, d.ifi_obytes)
        }
        return out
    }

    func speed() -> Speed {
        let now = Date(), cur = Self.readCounters()
        counters = cur
        defer { last = (cur, now) }
        guard let (prev, t0) = last else { return Speed() }
        let dt = now.timeIntervalSince(t0)
        guard dt > 0 else { return Speed() }
        var s = Speed()
        for (name, c) in cur {
            guard let p = prev[name] else { continue }
            let down = Double(c.0 &- p.0) / dt, up = Double(c.1 &- p.1) / dt
            if name.hasPrefix("pdp_ip") { s.cellDown += down; s.cellUp += up }
            else { s.wifiDown += down; s.wifiUp += up }
        }
        return s
    }
}

func formatSpeed(_ bps: Double) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .binary) + "/s"
}

/// Đo tốc độ thật bằng cách tải/lên dữ liệu thử (Cloudflare speed test).
@Observable
final class SpeedTestModel {
    var running = false
    var pingMs: Double?
    var downMbps: Double?
    var upMbps: Double?
    var error: String?

    @MainActor
    func run() async {
        guard !running else { return }
        running = true; error = nil; pingMs = nil; downMbps = nil; upMbps = nil
        defer { running = false }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: cfg)
        do {
            var t0 = Date()
            _ = try await session.data(from: URL(string: "https://speed.cloudflare.com/__down?bytes=0")!)
            pingMs = Date().timeIntervalSince(t0) * 1000

            t0 = Date()
            let (d, _) = try await session.data(from: URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")!)
            downMbps = Double(d.count) * 8 / Date().timeIntervalSince(t0) / 1_000_000

            var req = URLRequest(url: URL(string: "https://speed.cloudflare.com/__up")!)
            req.httpMethod = "POST"
            let body = Data(count: 8_000_000)
            t0 = Date()
            _ = try await session.upload(for: req, from: body)
            upMbps = Double(body.count) * 8 / Date().timeIntervalSince(t0) / 1_000_000
        } catch {
            self.error = error.localizedDescription
        }
    }
}
