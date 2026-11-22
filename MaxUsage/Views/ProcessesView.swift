import SwiftUI

struct ProcessesView: View {
    @Environment(SystemStore.self) private var s
    enum SortKey: String, CaseIterable { case ram = "RAM", cpu = "CPU", name = "Tên" }
    @State private var sort: SortKey = .ram
    @State private var search = ""
    @State private var userAppsOnly = false
    @State private var pendingKill: ProcInfo?

    private var list: [ProcInfo] {
        var l = s.processes
        if userAppsOnly { l = l.filter(\.isUserApp) }
        if !search.isEmpty { l = l.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        switch sort {
        case .ram: l.sort { $0.resident > $1.resident }
        case .cpu: l.sort { $0.cpuPercent > $1.cpuPercent }
        case .name: l.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return l
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Sắp xếp", selection: $sort) { ForEach(SortKey.allCases, id: \.self) { Text($0.rawValue) } }
                        .pickerStyle(.segmented)
                    Toggle("Chỉ ứng dụng người dùng", isOn: $userAppsOnly)
                    if s.processes.isEmpty {
                        Text("Không đọc được danh sách tiến trình. Cần ký app với entitlement (xem README).")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section("\(list.count) tiến trình") {
                    ForEach(list) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(p.name).font(.body.bold()).lineLimit(1)
                                Spacer()
                                Text(p.resident.bytesString).monospacedDigit()
                            }
                            HStack {
                                Text("PID \(p.pid) · \(p.threads) luồng").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "CPU %.1f%%", p.cpuPercent)).font(.caption).monospacedDigit()
                                    .foregroundStyle(usageColor(for: p.cpuPercent))
                            }
                        }
                        .swipeActions {
                            if !p.isCritical {
                                Button("Kill", role: .destructive) { pendingKill = p }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Tiến trình")
            .confirmationDialog("Buộc dừng \(pendingKill?.name ?? "")?", isPresented: Binding(get: { pendingKill != nil }, set: { if !$0 { pendingKill = nil } }),
                                titleVisibility: .visible) {
                Button("Buộc dừng (SIGKILL)", role: .destructive) {
                    if let p = pendingKill { ProcessMonitor.kill(p.pid) }
                    pendingKill = nil
                }
                Button("Hủy", role: .cancel) { pendingKill = nil }
            }
        }
    }
}
