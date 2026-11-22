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
                    else if let m = s.estCurrentMA { RowKV("Dòng (ước tính)", String(format: "%+.0f mA", m)) }
                    if let w = s.bestPowerW {
                        RowKV((w >= 0 ? "Công suất sạc" : "Công suất tiêu thụ") + (s.powerIsEstimate ? " (ước tính)" : ""),
                              String(format: "%.2f W", abs(w)))
                    } else {
                        Text(b.isCharging ? "Đang thu thập dữ liệu để ước tính công suất (cần vài phút, pin phải đổi ≥ 2%)."
                                          : "Cắm sạc để đo công suất sạc.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let p = b.systemPowerInW { RowKV("Công suất vào từ củ sạc", String(format: "%.2f W", p)) }
                    if let ad = b.adapterWatts { RowKV("Củ sạc", "\(ad) W") }
                    if !b.ioRegistryReadable {
                        Text("iOS chặn đọc AppleSmartBattery (không có entitlement). Công suất chỉ là ước tính từ tốc độ tăng %. Xem Thiết bị › Chẩn đoán.")
                            .font(.caption).foregroundStyle(.orange)
                    }
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
        // Dùng %/giờ từ dòng đo được hoặc ước tính
        let mA: Double
        let cap: Double
        if let a = b.amperageA, abs(a) > 0.02, let mx = b.maxCapacity ?? b.designCapacity { mA = a * 1000; cap = Double(mx) }
        else if let m = s.estCurrentMA, abs(m) > 20, let c = ChargeEstimator.capacityTable[sysctlString("hw.machine")] { mA = m; cap = c }
        else { return nil }
        let ratePerHour = mA / cap * 100            // %/giờ
        if mA > 0 { return "Đầy sau ~\(formatDuration(max(0, 100 - b.level) / ratePerHour * 3600))" }
        return "Dùng được ~\(formatDuration(b.level / abs(ratePerHour) * 3600))"
    }
}
