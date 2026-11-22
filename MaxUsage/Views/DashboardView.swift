import SwiftUI

struct DashboardView: View {
    @Environment(SystemStore.self) private var s

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        GaugeCard(title: "CPU", value: s.cpu.total,
                                  detail: "\(s.cpu.cores.count) nhân", systemImage: "cpu")
                        GaugeCard(title: "RAM", value: s.memory.usedPercent,
                                  detail: "\(s.memory.used.bytesString) / \(s.memory.total.bytesString) · trống \(s.memory.available.bytesString)",
                                  systemImage: "memorychip")
                        GaugeCard(title: "Ổ cứng", value: s.storage.usedPercent,
                                  detail: "Trống \(s.storage.freeRaw.bytesString)", systemImage: "internaldrive")
                        GaugeCard(title: "GPU", value: s.gpu.utilization ?? 0,
                                  detail: s.gpu.utilization == nil
                                      ? "\(s.gpu.name ?? "GPU") · iOS chặn đo tải"
                                      : "Render \(Int(s.gpu.rendererUtilization ?? 0))%",
                                  systemImage: "display",
                                  display: s.gpu.utilization == nil ? "N/A" : nil)
                        GaugeCard(title: "Pin", value: s.battery.level,
                                  detail: s.battery.isCharging ? "Đang sạc" : "Đang dùng", systemImage: "battery.75")
                        GaugeCard(title: "Nhiệt độ TB", value: tempBar,
                                  detail: "\(s.thermalState)" + (s.avgTemp.map { " · \($0.source)" } ?? ""),
                                  systemImage: "thermometer.medium",
                                  display: s.avgTemp.map { String(format: "%.1f°C", $0.value) } ?? "—")
                    }

                    coresCard
                    HistoryChart(title: "CPU", samples: s.cpuHistory, color: .blue, range: 0...100)
                    HistoryChart(title: "RAM", samples: s.memHistory, color: .purple, range: 0...100)
                    if !s.gpuHistory.isEmpty { HistoryChart(title: "GPU", samples: s.gpuHistory, color: .pink, range: 0...100) }
                    HistoryChart(title: "Nhiệt độ", samples: s.tempHistory, unit: "°C", color: .orange)

                    networkCard
                }
                .padding()
            }
            .navigationTitle("Max Usage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach([0.5, 1.0, 2.0, 5.0], id: \.self) { v in
                            Button("Cập nhật mỗi \(String(format: "%g", v))s") { s.setInterval(v) }
                        }
                    } label: { Image(systemName: "timer") }
                }
            }
        }
    }

    /// Độ dài thanh nhiệt: 25°C → 0%, 50°C → 100%.
    private var tempBar: Double {
        guard let t = s.avgTemp?.value else { return 0 }
        return min(max((t - 25) / 25 * 100, 0), 100)
    }

    private var coresCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Từng nhân CPU").font(.subheadline.bold())
            ForEach(Array(s.cpu.cores.enumerated()), id: \.offset) { i, v in
                HStack {
                    Text("Nhân \(i + 1)").font(.caption).frame(width: 52, alignment: .leading)
                    ProgressView(value: v, total: 100).tint(usageColor(for: v))
                    Text("\(Int(v))%").font(.caption).monospacedDigit().frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mạng").font(.subheadline.bold())
            RowKV("Wi-Fi ↓ / ↑", "\(formatSpeed(s.net.wifiDown)) / \(formatSpeed(s.net.wifiUp))")
            RowKV("Di động ↓ / ↑", "\(formatSpeed(s.net.cellDown)) / \(formatSpeed(s.net.cellUp))")
            if s.netCounters.isEmpty {
                Text("Không đọc được bộ đếm giao diện mạng.").font(.caption).foregroundStyle(.orange)
            }
            Divider()
            let t = s.speedTest
            HStack {
                Button { Task { await t.run() } } label: {
                    Label(t.running ? "Đang đo..." : "Đo tốc độ mạng thật", systemImage: "speedometer")
                }
                .disabled(t.running)
                Spacer()
            }
            if let p = t.pingMs { RowKV("Ping", String(format: "%.0f ms", p)) }
            if let d = t.downMbps { RowKV("Tải xuống", String(format: "%.1f Mbps", d)) }
            if let u = t.upMbps { RowKV("Tải lên", String(format: "%.1f Mbps", u)) }
            if let e = t.error { Text(e).font(.caption).foregroundStyle(.red) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
