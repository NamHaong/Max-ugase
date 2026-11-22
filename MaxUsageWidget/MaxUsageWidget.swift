import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let battery: BatteryInfo
    let memory: MemoryInfo
    let storage: StorageInfo
    let thermal: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry { snapshot() }
    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) { completion(snapshot()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        // iOS giới hạn tần suất; xin cập nhật mỗi 5 phút (hệ thống có thể giãn ra).
        let now = Date()
        let entries = (0..<6).map { i -> UsageEntry in
            var e = snapshot(); _ = i; e = UsageEntry(date: now.addingTimeInterval(Double(i) * 300),
                                                      battery: e.battery, memory: e.memory, storage: e.storage, thermal: e.thermal)
            return e
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(1800))))
    }
    private func snapshot() -> UsageEntry {
        UsageEntry(date: Date(), battery: BatteryMonitor.read(), memory: MemoryMonitor.read(),
                   storage: StorageMonitor.read(), thermal: ThermalMonitor.stateText)
    }
}

struct Ring: View {
    let value: Double, label: String, color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 7)
            Circle().trim(from: 0, to: min(max(value / 100, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(value))%").font(.caption.bold()).monospacedDigit()
                Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let e: UsageEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: e.battery.level, in: 0...100) { Image(systemName: "battery.100") } currentValueLabel: { Text("\(Int(e.battery.level))") }
                .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Pin \(Int(e.battery.level))%  RAM \(Int(e.memory.usedPercent))%")
                Text("Ổ \(Int(e.storage.usedPercent))%  \(e.thermal)")
                if let t = e.battery.temperatureC { Text(String(format: "%.1f°C", t)) }
            }.font(.caption2)
        case .systemSmall:
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Ring(value: e.battery.level, label: "Pin", color: .green)
                    Ring(value: e.memory.usedPercent, label: "RAM", color: .purple)
                }
                HStack(spacing: 6) {
                    Ring(value: e.storage.usedPercent, label: "Ổ", color: .blue)
                    Ring(value: thermalPct, label: "Nhiệt", color: .orange)
                }
            }.padding(4)
        default:
            HStack(spacing: 10) {
                Ring(value: e.battery.level, label: "Pin", color: .green)
                Ring(value: e.memory.usedPercent, label: "RAM", color: .purple)
                Ring(value: e.storage.usedPercent, label: "Ổ cứng", color: .blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.thermal).font(.caption.bold())
                    if let t = e.battery.temperatureC { Text(String(format: "%.1f °C", t)).font(.caption2) }
                    if let c = e.battery.cycleCount { Text("\(c) chu kỳ").font(.caption2) }
                    if let h = e.battery.healthPercent { Text(String(format: "Sức khỏe %.0f%%", h)).font(.caption2) }
                    Text("Trống \(e.storage.freeRaw.bytesString)").font(.caption2)
                }
            }.padding(4)
        }
    }

    private var thermalPct: Double {
        switch e.thermal { case "Bình thường": return 20; case "Hơi ấm": return 50; case "Nóng": return 80; default: return 100 }
    }
}

struct MaxUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MaxUsageWidget", provider: Provider()) { e in
            WidgetView(e: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Max Usage")
        .description("Pin, RAM, ổ cứng và nhiệt độ.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct MaxUsageBundle: WidgetBundle {
    var body: some Widget { MaxUsageWidget() }
}
