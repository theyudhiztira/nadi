import AppKit
import NadiCore
import NadiSensors
import SwiftUI

/// The dropdown panel. One scrolling column; each section has its own shape for what it shows.
struct PanelView: View {
    let store: LiveStore
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                PanelSections(store: store)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            Divider()
            PanelFooter(onQuit: onQuit)
        }
        .frame(width: PanelView.width)
    }

    static let width: CGFloat = 340
}

struct PanelSections: View {
    let store: LiveStore
    @ViewState private var ranking: ProcessRanking = .cpu

    var body: some View {
        let s = store.latest
        VStack(alignment: .leading, spacing: 14) {
            cpu(s)
            Divider()
            memory(s)
            Divider()
            temperatures(s)
            Divider()
            gpu(s)
            Divider()
            fans(s)
            Divider()
            power(s)
            Divider()
            network(s)
            Divider()
            disk(s)
            Divider()
            processes(s)
        }
    }

    // MARK: Sections

    private func cpu(_ s: Snapshot?) -> some View {
        PanelSection(title: "CPU", value: format(s?.cpu?.total, .cpu), alerting: MetricID.cpu.isAlerting(s?.cpu?.total)) {
            HistoryChart(store: store, series: [.init(metric: .cpu, name: "CPU")], alerting: MetricID.cpu.isAlerting(s?.cpu?.total))
            if let load = s?.cpu, let counts = CPUReader.coreCounts, counts.performance + counts.efficiency == load.perCore.count {
                // Apple Silicon numbers efficiency cores first.
                CoreBars(title: "Efficiency", loads: Array(load.perCore.prefix(counts.efficiency)))
                CoreBars(title: "Performance", loads: Array(load.perCore.suffix(counts.performance)))
            } else if let load = s?.cpu {
                CoreBars(title: "Cores", loads: load.perCore)
            }
        }
    }

    private func memory(_ s: Snapshot?) -> some View {
        let m = s?.memory
        return PanelSection(title: "Memory", value: format(m?.fraction, .memory), alerting: MetricID.memory.isAlerting(m?.fraction)) {
            HistoryChart(store: store, series: [.init(metric: .memory, name: "Memory")], alerting: MetricID.memory.isAlerting(m?.fraction))
            Facts([
                ("Used", m.map { "\(MetricFormatter.bytes(Double($0.usedBytes), binary: true)) of \(MetricFormatter.bytes(Double($0.totalBytes), binary: true))" }),
                ("Pressure", m?.pressure.map(\.label)),
                ("Swap", m?.swapUsedBytes.map { MetricFormatter.bytes(Double($0), binary: true) }),
            ])
        }
    }

    private func temperatures(_ s: Snapshot?) -> some View {
        PanelSection(title: "Temperatures", value: format(s?.cpuTemperature, .cpuTemperature),
                alerting: MetricID.cpuTemperature.isAlerting(s?.cpuTemperature)) {
            HistoryChart(store: store, series: [.init(metric: .cpuTemperature, name: "CPU"), .init(metric: .gpuTemperature, name: "GPU")])
            Facts([
                ("CPU", Optional(format(s?.cpuTemperature, .cpuTemperature))),
                ("GPU", Optional(format(s?.gpuTemperature, .gpuTemperature))),
            ], legend: true)
        }
    }

    private func gpu(_ s: Snapshot?) -> some View {
        PanelSection(title: "GPU", value: format(s?.gpuUsage, .gpu)) {
            HistoryChart(store: store, series: [.init(metric: .gpu, name: "GPU")])
            Facts([("Power", s?.energy?.gpuWatts.map(MetricFormatter.watts))])
        }
    }

    @ViewBuilder
    private func fans(_ s: Snapshot?) -> some View {
        let speeds = s?.fanRPM
        PanelSection(title: "Fans", value: speeds?.max().map(rpm) ?? MetricFormatter.missing) {
            if let speeds, speeds.isEmpty {
                Note("This Mac has no fans.")
            } else {
                HistoryChart(store: store, series: [.init(metric: .fan, name: "Fan")])
                Facts((speeds ?? []).enumerated().map { ("Fan \($0.offset + 1)", Optional(rpm($0.element))) })
            }
        }
    }

    @ViewBuilder
    private func power(_ s: Snapshot?) -> some View {
        let p = s?.power
        PanelSection(title: "Power & Battery", value: format(p?.menuBarWatts, .power)) {
            if store.latest != nil, p == nil {
                Note("No battery found.")
            } else {
                HistoryChart(store: store, series: [.init(metric: .power, name: p?.externalConnected == false ? "System draw" : "Adapter input")])
                Facts([
                    (p?.externalConnected == false ? "System draw" : "Adapter input", p?.menuBarWatts.map(MetricFormatter.watts)),
                    ("Adapter rating", p?.externalConnected == true ? p?.adapterRatingWatts.map(MetricFormatter.watts) : nil),
                    ("Battery", p?.batteryWatts.map { String(format: "%+.1fW", $0) }),
                    ("CPU", s?.energy?.cpuWatts.map(MetricFormatter.watts)),
                    ("Whole system", s?.energy?.systemWatts.map(MetricFormatter.watts)),
                    ("Charge", p?.percent.map { "\($0)%" }),
                    ("State", p.map(chargeState)),
                    (p?.isCharging == true ? "Time to full" : "Time left", p?.timeRemainingMinutes.map(duration)),
                    ("Health", p?.healthFraction.map { "\(Int(($0 * 100).rounded()))%" }),
                    ("Cycles", p?.cycleCount.map(String.init)),
                ])
            }
        }
    }

    private func network(_ s: Snapshot?) -> some View {
        PanelSection(title: "Network", value: nil) {
            HistoryChart(store: store, series: [.init(metric: .networkIn, name: "Down"), .init(metric: .networkOut, name: "Up")])
            Facts([
                ("Down", s?.network.map { MetricFormatter.bytesPerSecond($0.inPerSecond) }),
                ("Up", s?.network.map { MetricFormatter.bytesPerSecond($0.outPerSecond) }),
            ], legend: true)
        }
    }

    private func disk(_ s: Snapshot?) -> some View {
        PanelSection(title: "Disk", value: s?.diskFreeBytes.map { "\(MetricFormatter.bytes(Double($0))) free" }) {
            HistoryChart(store: store, series: [.init(metric: .diskRead, name: "Read"), .init(metric: .diskWrite, name: "Write")])
            Facts([
                ("Read", s?.disk.map { MetricFormatter.bytesPerSecond($0.inPerSecond) }),
                ("Write", s?.disk.map { MetricFormatter.bytesPerSecond($0.outPerSecond) }),
            ], legend: true)
        }
    }

    private func processes(_ s: Snapshot?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top processes").font(.system(size: 13, weight: .semibold))
                Spacer()
                Picker("Sort by", selection: $ranking) {
                    Text("CPU").tag(ProcessRanking.cpu)
                    Text("Memory").tag(ProcessRanking.memory)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if let usage = s?.processes {
                let top = TopProcesses.top(5, of: usage, by: ranking)
                ForEach(top) { process in
                    HStack {
                        Text(process.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(ranking == .cpu
                             ? "\(Int((process.cpu * 100).rounded()))%"
                             : MetricFormatter.bytes(Double(process.memoryBytes), binary: true))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12))
                }
            } else {
                Note("Measuring processes…")
            }
        }
    }

    // MARK: Helpers

    private func format(_ value: Double?, _ metric: MetricID) -> String {
        MetricFormatter.format(value, for: metric)
    }

    private func rpm(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) rpm"
    }

    private func duration(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    private func chargeState(_ p: PowerStatus) -> String {
        if !p.externalConnected { return "On battery" }
        if p.fullyCharged { return "Charged" }
        if p.isCharging { return "Charging" }
        return "Not charging"
    }
}

private struct PanelSection<Content: View>: View {
    let title: String
    let value: String?
    var alerting = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let value {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(alerting ? Color.red : Color.primary)
                }
            }
            content
        }
        .accessibilityElement(children: .contain)
    }
}

/// Label and value pairs in two columns. A nil value hides its row. With `legend`, the first two labels
/// get the chart's series colors.
private struct Facts: View {
    let rows: [(String, String?)]
    var legend = false

    init(_ rows: [(String, String?)], legend: Bool = false) {
        self.rows = rows
        self.legend = legend
    }

    var body: some View {
        let visible = rows.enumerated().filter { $0.element.1 != nil }
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
            ForEach(visible, id: \.offset) { entry in
                GridRow {
                    HStack(spacing: 5) {
                        if legend {
                            Circle()
                                .fill(entry.offset == 0 ? Color.accentColor : Color.secondary)
                                .frame(width: 6, height: 6)
                        }
                        Text(entry.element.0).foregroundStyle(.secondary)
                    }
                    Text(entry.element.1 ?? "")
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 12))
            }
        }
    }
}

private struct CoreBars: View {
    let title: String
    let loads: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(loads.enumerated()), id: \.offset) { _, load in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 1.5).fill(Color.secondary.opacity(0.2))
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.accentColor)
                            .frame(height: max(1, 18 * load))
                    }
                    // Fixed width so two efficiency cores and eight performance cores read at the same scale.
                    .frame(width: 12, height: 18)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) cores: \(loads.map { "\(Int(($0 * 100).rounded()))%" }.joined(separator: ", "))")
    }
}

private struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
    }
}

private struct PanelFooter: View {
    let onQuit: () -> Void

    var body: some View {
        HStack {
            // TODO(phase 6): open the settings window.
            Button("Settings") {}
                .disabled(true)
            Text("Coming soon")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            // Selectable so a bug report can paste it.
            Text(Self.version)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Button("Quit Nadi", action: onQuit)
                .keyboardShortcut("q")
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// "v0.0.1 (1)" from Info.plist. A bare binary outside Nadi.app has no Info.plist.
    private static let version: String = {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "Dev build" }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "v\(short) (\($0))" } ?? "v\(short)"
    }()
}

extension MemoryPressure {
    var label: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}
