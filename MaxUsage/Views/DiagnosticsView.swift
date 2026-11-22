import SwiftUI

enum Diagnostics {
    static func dump(store: SystemStore) -> String {
        var out = "== Tổng quát ==\n"
        out += "model=\(sysctlString("hw.machine")) ios=\(UIDevice.current.systemVersion)\n"
        out += "tiến trình đọc được: \(store.processes.count)\n"
        out += "cảm biến HID: \(store.sensors.count)\n"
        out += "bộ đếm mạng: " + store.netCounters.map { "\($0.key)=↓\($0.value.0) ↑\($0.value.1)" }.sorted().joined(separator: ", ") + "\n"
        out += "RAM: total=\(store.memory.total) used=\(store.memory.used) app=\(store.memory.appMemory) wired=\(store.memory.wired) comp=\(store.memory.compressed) free=\(store.memory.free) inactive=\(store.memory.inactive) cached=\(store.memory.cached)\n"
        out += "GPU metal: \(store.gpu.name ?? "nil")\n\n"

        for name in ["AppleSmartBattery", "IOAccelerator", "AGXAccelerator", "IOGPU"] {
            let items = MUReadIORegistryAll(name)
            out += "== \(name): \(items.count) service ==\n"
            for (i, d) in items.enumerated() {
                out += "-- #\(i) --\n"
                for k in d.keys.compactMap({ $0 as? String }).sorted() {
                    out += "\(k) = \(String(String(describing: d[k] ?? "nil").replacingOccurrences(of: "\n", with: " ").prefix(300)))\n"
                }
            }
            out += "\n"
        }
        return out
    }
}

struct DiagnosticsView: View {
    @Environment(SystemStore.self) private var s
    @State private var text = "Đang đọc..."

    var body: some View {
        ScrollView {
            Text(text).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding()
        }
        .navigationTitle("Chẩn đoán")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ShareLink(item: text) } }
        .onAppear { text = Diagnostics.dump(store: s) }
    }
}
