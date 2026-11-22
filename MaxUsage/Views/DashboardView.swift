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
                                  detail: "\(s.memory.used.bytesString) / \(s.memory.total.bytesString)", systemImage: "memorychip")
                        GaugeCard(title: "Ổ cứng", value: s.storage.usedPercent,
                                  detail: "Trống \(s.storage.freeRaw.bytesString)", systemImage: "internaldrive")
                        GaugeCard(title: "GPU", value: s.gpu.utilization ?? 0,
                                  detail: s.gpu.utilization == nil ? "Không đọc được" : "Render \(Int(s.gpu.rendererUtilization ?? 0))%",
                                  systemImage: "display")
                        GaugeCard(title: "Pin", value: s.battery.level,
                                  detail: s.battery.isCharging ? "Đang sạc" : "Đang dùng", systemImage: "battery.75")
                        GaugeCard(title: "Nhiệt", value: thermalPercent,
                                  detail: s.thermalState, systemImage: "thermometer.medium")
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

    private var thermalPercent: Double {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return 20
        case .fair: return 50
        case .serious: return 80
        case .critical: return 100
        @unknown default: return 0
        }
    }

    private var coresCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Từng nhân CPU").font(.subheadline.bold())
            ForEach(Array(s.cpu.cores.enumerated()), id: \.offset) { i, v in
                HStack {
                    Text("Nhân \(i + 1)").font(.caption).frame(width: 52, alignment: .leading)
                    ProgressView(value: v, total: 100).tint(tint(for: v))
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
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
