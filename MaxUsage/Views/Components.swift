import SwiftUI
import Charts

func usageColor(for pct: Double) -> Color { pct < 60 ? .green : (pct < 85 ? .orange : .red) }

struct GaugeCard: View {
    let title: String
    let value: Double          // 0...100
    let detail: String
    var systemImage: String = "cpu"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(value))%").font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
            ProgressView(value: min(max(value, 0), 100), total: 100).tint(usageColor(for: value))
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HistoryChart: View {
    let title: String
    let samples: [Sample]
    var unit = "%"
    var color: Color = .blue
    var range: ClosedRange<Double>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                if let l = samples.last { Text(String(format: "%.1f%@", l.value, unit)).font(.subheadline).monospacedDigit() }
            }
            if samples.count > 1 {
                Chart(samples) {
                    LineMark(x: .value("t", $0.time), y: .value("v", $0.value)).foregroundStyle(color)
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("t", $0.time), y: .value("v", $0.value)).foregroundStyle(color.opacity(0.15))
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: range ?? autoRange)
                .frame(height: 90)
            } else {
                Text("Chưa có dữ liệu").font(.caption).foregroundStyle(.secondary).frame(height: 90)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var autoRange: ClosedRange<Double> {
        let v = samples.map(\.value)
        let lo = v.min() ?? 0, hi = v.max() ?? 1
        return (lo - 1)...(hi + 1)
    }
}

struct RowKV: View {
    let k: String; let v: String
    init(_ k: String, _ v: String) { self.k = k; self.v = v }
    var body: some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).monospacedDigit().multilineTextAlignment(.trailing) }
    }
}
