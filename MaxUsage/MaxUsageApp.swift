import SwiftUI

@main
struct MaxUsageApp: App {
    @State private var store = SystemStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onAppear { store.start() }
                .onChange(of: phase) { _, p in p == .active ? store.start() : store.stop() }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Tổng quan", systemImage: "gauge.with.dots.needle.67percent") }
            ProcessesView().tabItem { Label("Tiến trình", systemImage: "list.bullet.rectangle") }
            SensorsView().tabItem { Label("Nhiệt độ", systemImage: "thermometer.medium") }
            BatteryView().tabItem { Label("Pin", systemImage: "battery.100.bolt") }
            CleanerView().tabItem { Label("Dọn dẹp", systemImage: "trash.circle") }
            InfoView().tabItem { Label("Thiết bị", systemImage: "iphone") }
        }
    }
}
