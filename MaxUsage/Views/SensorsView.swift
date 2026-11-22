import SwiftUI

struct SensorsView: View {
    @Environment(SystemStore.self) private var s

    private var grouped: [(String, [ThermalSensor])] {
        Dictionary(grouping: s.sensors, by: \.category).sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Trạng thái nhiệt hệ thống") {
                    RowKV("iOS báo", s.thermalState)
                    if let t = s.battery.temperatureC { RowKV("Nhiệt độ pin", String(format: "%.1f °C", t)) }
                    if let c = ThermalMonitor.average(of: "CPU / SoC", in: s.sensors) { RowKV("CPU/SoC (TB)", String(format: "%.1f °C", c)) }
                    if let g = ThermalMonitor.average(of: "GPU", in: s.sensors) { RowKV("GPU (TB)", String(format: "%.1f °C", g)) }
                }
                if s.sensors.isEmpty {
                    Section { Text("Không đọc được cảm biến HID. Cần entitlement com.apple.private.hid.client.event-dispatch (TrollStore).")
                        .font(.caption).foregroundStyle(.orange) }
                }
                ForEach(grouped, id: \.0) { cat, items in
                    Section(cat) {
                        ForEach(items) { sen in
                            HStack {
                                Text(sen.name).font(.callout)
                                Spacer()
                                Text(String(format: "%.1f °C", sen.celsius)).monospacedDigit()
                                    .foregroundStyle(sen.celsius > 45 ? .red : (sen.celsius > 38 ? .orange : .green))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nhiệt độ")
        }
    }
}
