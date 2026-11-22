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
    var avgTemp: (value: Double, source: String)?
    var net = NetworkMonitor.Speed()
    var netCounters: [String: (UInt32, UInt32)] = [:]
    var processes: [ProcInfo] = []
    var estPowerW: Double?
    var estCurrentMA: Double?
    let device = DeviceDetails()
    let speedTest = SpeedTestModel()

    /// Công suất tốt nhất có: đo thật, nếu không thì ước tính.
    var bestPowerW: Double? { battery.powerW ?? estPowerW }
    var powerIsEstimate: Bool { battery.powerW == nil && estPowerW != nil }

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
    private let chargeEst = ChargeEstimator()
    private var timer: Timer?
    private var tick = 0

    func start() {
        guard timer == nil else { return }
        refresh()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)   // vẫn chạy khi đang cuộn
        timer = t
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
        netCounters = netMon.counters
        thermalState = ThermalMonitor.stateText
        sensors = ThermalMonitor.sensors()
        avgTemp = ThermalMonitor.overallAverage(sensors: sensors, battery: battery.temperatureC)
        if tick % 5 == 1 { storage = StorageMonitor.read() }
        if tick % 2 == 1 { processes = procMon.read() }

        chargeEst.update(level: battery.level, charging: battery.isCharging, designCapacity: battery.designCapacity)
        estPowerW = chargeEst.estimatedPowerW
        estCurrentMA = chargeEst.estimatedCurrentMA

        push(&cpuHistory, cpu.total)
        push(&memHistory, memory.usedPercent)
        push(&gpuHistory, gpu.utilization)
        push(&tempHistory, avgTemp?.value)
        push(&powerHistory, bestPowerW)
    }
}
