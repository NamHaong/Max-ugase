import SwiftUI

struct BatteryView: View {
    @Environment(SystemStore.self) private var s
    @AppStorage("chargeAlertLevel") private var alertLevel = 80

    var body: some View {
        let b = s.battery
        NavigationStack {
            List {
                Section("Hiện tại") {
                    RowKV("Mức pin", String(format: "%.0f%%", b.level))
                    RowKV("Trạng thái", stateText(b))
                    RowKV("Chế độ tiết kiệm pin", b.lowPower ? "Bật" : "Tắt")
                    if let t = b.temperatureC { RowKV("Nhiệt độ", String(format: "%.1f °C", t)) }
                }
                Section("Điện (đọc từ IORegistry)") {
                    if let v = b.voltageV { RowKV("Điện áp", String(format: "%.3f V", v)) }
                    if let a = b.amperageA { RowKV("Dòng", String(format: "%+.0f mA", a * 1000)) }
                    if let w = b.powerW { RowKV(w >= 0 ? "Công suất sạc" : "Công suất tiêu thụ", String(format: "%.2f W", abs(w))) }
                    if let ad = b.adapterWatts { RowKV("Củ sạc", "\(ad) W") }
                    if b.voltageV == nil { Text("Không đọc được AppleSmartBattery.").font(.caption).foregroundStyle(.orange) }
                }
                Section("Sức khỏe pin") {
                    if let h = b.healthPercent { RowKV("Độ chai (dung lượng tối đa)", String(format: "%.1f%%", h)) }
                    if let c = b.cycleCount { RowKV("Số chu kỳ sạc", "\(c)") }
                    if let d = b.designCapacity { RowKV("Dung lượng thiết kế", "\(d) mAh") }
                    if let m = b.maxCapacity { RowKV("Dung lượng tối đa hiện tại", "\(m) mAh") }
                    if let c = b.currentCapacity { RowKV("Dung lượng hiện tại", "\(c) mAh") }
                    if let eta = estimate(b) { RowKV("Ước tính", eta) }
                }
                Section {
                    HistoryChart(title: "Công suất (W, âm = xả)", samples: s.powerHistory, unit: " W", color: .green)
                        .listRowInsets(EdgeInsets())
                }
                Section("Cảnh báo sạc") {
                    Stepper("Nhắc rút sạc ở \(alertLevel)%", value: $alertLevel, in: 50...100, step: 5)
                    Text("Thông báo cục bộ khi pin đạt mức này lúc đang sạc.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Pin")
            .onChange(of: s.battery.level) { _, lvl in ChargeAlert.check(level: lvl, charging: s.battery.isCharging, threshold: alertLevel) }
        }
    }

    private func stateText(_ b: BatteryInfo) -> String {
        switch b.state {
        case .charging: return "Đang sạc"
        case .full: return "Đã đầy"
        case .unplugged: return "Không sạc"
        default: return "Không rõ"
        }
    }

    private func estimate(_ b: BatteryInfo) -> String? {
        guard let cur = b.currentCapacity, let mx = b.maxCapacity, let a = b.amperageA, abs(a) > 0.02 else { return nil }
        let mA = abs(a) * 1000
        if a > 0 {
            let hours = Double(max(0, mx - cur)) / mA
            return "Đầy sau ~\(formatDuration(hours * 3600))"
        } else {
            return "Dùng được ~\(formatDuration(Double(cur) / mA * 3600))"
        }
    }
}
