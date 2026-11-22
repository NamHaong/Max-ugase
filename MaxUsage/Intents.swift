import AppIntents

struct SystemStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Xem tình trạng máy"
    static var description = IntentDescription("Pin, RAM, ổ cứng, nhiệt độ.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let b = BatteryMonitor.read(), m = MemoryMonitor.read(), s = StorageMonitor.read()
        var text = "Pin \(Int(b.level))%"
        if let t = b.temperatureC { text += String(format: " (%.1f°C)", t) }
        text += ", RAM \(Int(m.usedPercent))%, ổ cứng trống \(s.freeRaw.bytesString), nhiệt \(ThermalMonitor.stateText)."
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

struct BatteryIntent: AppIntent {
    static var title: LocalizedStringResource = "Xem pin chi tiết"
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let b = BatteryMonitor.read()
        var t = "Pin \(Int(b.level))%"
        if let h = b.healthPercent { t += String(format: ", sức khỏe %.0f%%", h) }
        if let c = b.cycleCount { t += ", \(c) chu kỳ" }
        if let w = b.powerW { t += String(format: ", %.1fW", w) }
        return .result(value: t, dialog: IntentDialog(stringLiteral: t))
    }
}

struct FreeStorageIntent: AppIntent {
    static var title: LocalizedStringResource = "Dung lượng trống"
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let t = "Còn trống \(StorageMonitor.read().freeRaw.bytesString)."
        return .result(value: t, dialog: IntentDialog(stringLiteral: t))
    }
}

struct MaxUsageShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SystemStatusIntent(), phrases: ["Xem tình trạng máy bằng \(.applicationName)"],
                    shortTitle: "Tình trạng máy", systemImageName: "gauge")
        AppShortcut(intent: BatteryIntent(), phrases: ["Pin bằng \(.applicationName)"],
                    shortTitle: "Pin", systemImageName: "battery.100")
        AppShortcut(intent: FreeStorageIntent(), phrases: ["Dung lượng trống bằng \(.applicationName)"],
                    shortTitle: "Dung lượng", systemImageName: "internaldrive")
    }
}
