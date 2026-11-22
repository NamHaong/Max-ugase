import Foundation
import SwiftUI
import Observation

struct Sample: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}

@Observable
final class SystemStore {
    // Giá trị hiện tại
    var cpu = CPUMonitor.Reading(total: 0, cores: [])
    var memory = MemoryInfo()
    var storage = StorageInfo()
    var battery = BatteryInfo()
    var gpu = GPUInfo()
    var sensors: [ThermalSensor] = []
    var thermalState = ThermalMonitor.stateText
    var net = NetworkMonitor.Speed()
    var processes: [ProcInfo] = []
    let device = DeviceDetails()

    // Lịch sử cho biểu đồ (giữ 120 mẫu)
    var cpuHistory: [Sample] = []
    var memHistory: [Sample] = []
    var tempHistory: [Sample] = []
    var powerHistory: [Sample] = []
    var gpuHistory: [Sample] = []

    var interval: Double = 1.0
    private let cpuMon = CPUMonitor()
    private let procMon = ProcessMonitor()
    private let netMon = NetworkMonitor()
    private var timer: Timer?
    private var tick = 0

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stop() { timer?.invalidate(); timer = nil }

    func setInterval(_ v: Double) { interval = v; stop(); start() }

    private func push(_ arr: inout [Sample], _ v: Double?) {
        guard let v else { return }
        arr.append(Sample(time: Date(), value: v))
        if arr.count > 120 { arr.removeFirst(arr.count - 120) }
    }

    func refresh() {
        tick += 1
        cpu = cpuMon.read()
        memory = MemoryMonitor.read()
        battery = BatteryMonitor.read()
        gpu = GPUMonitor.read()
        net = netMon.speed()
        thermalState = ThermalMonitor.stateText
        sensors = ThermalMonitor.sensors()
        if tick % 5 == 1 { storage = StorageMonitor.read() }
        if tick % 2 == 1 { processes = procMon.read() }

        push(&cpuHistory, cpu.total)
        push(&memHistory, memory.usedPercent)
        push(&gpuHistory, gpu.utilization)
        push(&tempHistory, battery.temperatureC ?? ThermalMonitor.average(of: "CPU / SoC", in: sensors))
        push(&powerHistory, battery.powerW)
    }
}
