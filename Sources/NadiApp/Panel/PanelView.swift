import AppKit
import NadiCore
import NadiSensors
import SwiftUI

/// The dropdown panel. One scrolling column; each section has its own shape for what it shows.
struct PanelView: View {
    let store: LiveStore
    let keepAwake: KeepAwake
    let updateChecker: UpdateChecker
    let onQuit: () -> Void
    let settings: SettingsStore
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PanelTopRows(
                update: updateChecker.available,
                currentVersion: currentVersion
            )
            ScrollView {
                PanelSections(store: store, temperatureUnit: settings.settings.temperatureUnit)
            }
            PanelBottomRows(keepAwake: keepAwake, onQuit: onQuit, onOpenSettings: onOpenSettings)
        }
        .frame(width: PanelView.width)
    }

    private var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static let width: CGFloat = 340
}

extension Color {
    static let panelSecondary = Color(
        NSColor(name: NSColor.Name("NadiPanelSecondary"), dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(red: 172 / 255.0, green: 172 / 255.0, blue: 176 / 255.0, alpha: 1)
            }
            return NSColor(red: 94 / 255.0, green: 94 / 255.0, blue: 94 / 255.0, alpha: 1)
        })
    )
}

struct PanelTopRows: View {
    let update: AvailableUpdate?
    let currentVersion: String?

    var body: some View {
        if let update, let currentVersion {
            UpdateRow(update: update, currentVersion: currentVersion)
        }
    }
}

struct PanelBottomRows: View {
    let keepAwake: KeepAwake
    let onQuit: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            KeepAwakeRow(keepAwake: keepAwake)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

            HStack(spacing: 8) {
                Button(action: onOpenSettings) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                }
                .buttonStyle(PanelFooterButtonStyle())

                Button(action: onQuit) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                }
                .buttonStyle(PanelFooterButtonStyle())
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }
}

struct PanelSections: View {
    let store: LiveStore
    var temperatureUnit: TemperatureUnit = .celsius
    @ViewState private var ranking: ProcessRanking = .cpu

    var body: some View {
        let s = store.latest
        VStack(alignment: .leading, spacing: 0) {
            cpu(s)
            memory(s)
            temperatures(s)
            gpu(s)
            fans(s)
            power(s)
            network(s)
            disk(s)
            processes(s)
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private func cpu(_ s: Snapshot?) -> some View {
        PanelSection(title: "CPU", first: true) {
            VStack(spacing: 0) {
                HStack {
                    LeadNumber(reading: MetricFormatter.reading(s?.cpu?.total, for: .cpu))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                if let load = s?.cpu, let counts = CPUReader.coreCounts, counts.performance + counts.efficiency == load.perCore.count {
                    // Apple Silicon numbers efficiency cores first.
                    let columns = max(counts.efficiency, counts.performance)
                    VStack(spacing: 4) {
                        CoreBars(title: "Efficiency", loads: Array(load.perCore.prefix(counts.efficiency)), columns: columns)
                        CoreBars(title: "Performance", loads: Array(load.perCore.suffix(counts.performance)), columns: columns)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                } else if let load = s?.cpu {
                    CoreBars(title: "Cores", loads: load.perCore, columns: load.perCore.count)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                }
                HistoryChart(store: store, series: [.init(metric: .cpu, name: "CPU")])
                    .frame(height: 46)
                    .padding(.top, 10)
                TimeAxis()
                    .padding(.horizontal, 14)
                    .padding(.top, 3)
            }
        }
    }

    private func memory(_ s: Snapshot?) -> some View {
        let m = s?.memory
        return PanelSection(title: "Memory") {
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    LeadNumber(reading: MetricFormatter.reading(m?.fraction, for: .memory))
                    Spacer(minLength: 0)
                    if let m {
                        SideFact(label: "Used", value: "\(MetricFormatter.bytes(Double(m.usedBytes), binary: true)) of \(MetricFormatter.bytes(Double(m.totalBytes), binary: true))")
                    }
                }
                .padding(.horizontal, 14)
                HistoryChart(store: store, series: [.init(metric: .memory, name: "Memory")])
                    .frame(height: 46)
                    .padding(.top, 10)
                Facts([
                    ("Pressure", m?.pressure.map(\.label)),
                    ("Swap", m?.swapUsedBytes.map { MetricFormatter.bytes(Double($0), binary: true) }),
                ])
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }
        }
    }

    private func temperatures(_ s: Snapshot?) -> some View {
        PanelSection(title: "Temperatures") {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 18) {
                    LeadNumber(reading: MetricFormatter.reading(s?.cpuTemperature, for: .cpuTemperature, temperatureUnit: temperatureUnit), label: "CPU", tint: .accentColor)
                    LeadNumber(reading: MetricFormatter.reading(s?.gpuTemperature, for: .gpuTemperature, temperatureUnit: temperatureUnit), label: "GPU", tint: .panelSecondary, secondary: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                HistoryChart(store: store, series: [.init(metric: .cpuTemperature, name: "CPU"), .init(metric: .gpuTemperature, name: "GPU")], temperatureUnit: temperatureUnit)
                    .frame(height: 46)
                    .padding(.top, 10)
            }
        }
    }

    private func gpu(_ s: Snapshot?) -> some View {
        PanelSection(title: "GPU") {
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    LeadNumber(reading: MetricFormatter.reading(s?.gpuUsage, for: .gpu))
                    Spacer(minLength: 0)
                    SideFact(label: "Power", value: s?.energy?.gpuWatts.map(MetricFormatter.watts))
                }
                .padding(.horizontal, 14)
                HistoryChart(store: store, series: [.init(metric: .gpu, name: "GPU")])
                    .frame(height: 46)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func fans(_ s: Snapshot?) -> some View {
        let speeds = s?.fanRPM
        PanelSection(title: "Fans") {
            VStack(spacing: 0) {
                HStack {
                    LeadNumber(reading: MetricFormatter.reading(speeds?.max().map(rpm) ?? MetricFormatter.missing))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                if let speeds, speeds.isEmpty {
                    Note("No fans")
                        .frame(height: 46)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                } else {
                    HistoryChart(store: store, series: [.init(metric: .fan, name: "Fan")])
                        .frame(height: 46)
                        .padding(.top, 10)
                    Facts(speeds.map { $0.enumerated().map { ("Fan \($0.offset + 1)", Optional(rpm($0.element))) } } ?? [])
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func power(_ s: Snapshot?) -> some View {
        let p = s?.power
        PanelSection(title: "Power") {
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    LeadNumber(
                        reading: MetricFormatter.reading(p?.menuBarWatts, for: .power),
                        label: p?.externalConnected == false ? "System" : "Adapter"
                    )
                    Spacer(minLength: 0)
                    SideFact(label: "Charge", value: p?.percent.map { "\($0)%" })
                }
                .padding(.horizontal, 14)
                if store.latest != nil, p == nil {
                    Note("No battery")
                        .frame(height: 46)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                } else {
                    HistoryChart(store: store, series: [.init(metric: .power, name: p?.externalConnected == false ? "System" : "Adapter")])
                        .frame(height: 46)
                        .padding(.top, 10)
                    Facts([
                        ("Rated", p?.externalConnected == true ? p?.adapterRatingWatts.map(MetricFormatter.watts) : nil),
                        ("Battery", p?.batteryWatts.map { String(format: "%+.1fW", $0) }),
                        ("CPU", s?.energy?.cpuWatts.map(MetricFormatter.watts)),
                        ("System", s?.energy?.systemWatts.map(MetricFormatter.watts)),
                        ("State", p.map(chargeState)),
                        (p?.isCharging == true ? "Time to full" : "Time left", p?.timeRemainingMinutes.map(duration)),
                        ("Health", p?.healthFraction.map { "\(Int(($0 * 100).rounded()))%" }),
                        ("Cycles", p?.cycleCount.map(String.init)),
                    ])
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }
            }
        }
    }

    private func network(_ s: Snapshot?) -> some View {
        PanelSection(title: "Network") {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 18) {
                    LeadNumber(reading: MetricFormatter.reading(s?.network.map { $0.inPerSecond }, for: .networkIn), label: "Down", tint: .accentColor)
                    LeadNumber(reading: MetricFormatter.reading(s?.network.map { $0.outPerSecond }, for: .networkOut), label: "Up", tint: .panelSecondary, secondary: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                HistoryChart(store: store, series: [.init(metric: .networkIn, name: "Down"), .init(metric: .networkOut, name: "Up")])
                    .frame(height: 46)
                    .padding(.top, 10)
            }
        }
    }

    private func disk(_ s: Snapshot?) -> some View {
        PanelSection(title: "Disk") {
            VStack(spacing: 0) {
                HStack {
                    LeadNumber(reading: MetricFormatter.reading(s?.diskFreeBytes.map { "\(MetricFormatter.bytes(Double($0))) free" } ?? MetricFormatter.missing))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                HistoryChart(store: store, series: [.init(metric: .diskRead, name: "Read"), .init(metric: .diskWrite, name: "Write")])
                    .frame(height: 46)
                    .padding(.top, 10)
                Facts([
                    ("Read", s?.disk.map { MetricFormatter.bytesPerSecond($0.inPerSecond) }),
                    ("Write", s?.disk.map { MetricFormatter.bytesPerSecond($0.outPerSecond) }),
                ], legend: true)
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }
        }
    }

    private func processes(_ s: Snapshot?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Processes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.panelSecondary)
                Spacer()
                Picker("Sort by", selection: $ranking) {
                    Text("CPU").tag(ProcessRanking.cpu)
                    Text("Memory").tag(ProcessRanking.memory)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }
            if let usage = s?.processes {
                let top = TopProcesses.top(5, of: usage, by: ranking)
                ForEach(top) { process in
                    HStack(spacing: 6) {
                        Image(nsImage: ProcessIcon.icon(for: process.pid, name: process.name))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                        GeometryReader { geometry in
                            Text(middleTruncated(process.name, width: min(geometry.size.width, 160)))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1)
                        }
                        .frame(maxWidth: .infinity)
                        Text(ranking == .cpu
                             ? "\(Int((process.cpu * 100).rounded()))%"
                             : MetricFormatter.bytes(Double(process.memoryBytes), binary: true))
                            .monospacedDigit()
                            .foregroundStyle(Color.panelSecondary)
                            .fixedSize()
                    }
                    .font(.system(size: 12))
                    .frame(height: 21)
                }
            } else {
                Note("Measuring…")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .accessibilityElement(children: .contain)
    }

    private func middleTruncated(_ name: String, width: CGFloat) -> String {
        let font = NSFont.systemFont(ofSize: 12)
        func fits(_ text: String) -> Bool {
            (text as NSString).size(withAttributes: [.font: font]).width <= width
        }
        guard !fits(name) else { return name }
        let characters = Array(name)
        for retained in stride(from: characters.count - 1, through: 0, by: -1) {
            let leading = Int(Double(retained) * 0.7)
            let trailing = retained - leading
            let candidate = String(characters.prefix(leading)) + "…" + String(characters.suffix(trailing))
            if fits(candidate) { return candidate }
        }
        return "…"
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
    var first = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.panelSecondary)
                .frame(height: 18, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, first ? 16 : 20)
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
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(visible, id: \.offset) { entry in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        if legend {
                            Circle()
                                .fill(entry.offset == 0 ? Color.accentColor : Color.panelSecondary)
                                .frame(width: 6, height: 6)
                        }
                        Text(entry.element.0)
                            .foregroundStyle(Color.panelSecondary)
                    }
                    .font(.system(size: 11))
                    Text(entry.element.1 ?? "")
                        .font(.system(size: 13))
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct LeadNumber: View {
    let reading: Reading
    var label: String? = nil
    var tint: Color? = nil
    var secondary = false

    private var value: String { reading.number + (reading.spaced ? " " : "") + reading.unit }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: reading.spaced ? 3 : 1) {
                Text(reading.number)
                    .font(.system(size: secondary ? 20 : 28, weight: .semibold))
                    .monospacedDigit()
                    .tracking(secondary ? 0 : -0.2)
                if !reading.unit.isEmpty {
                    Text(reading.unit)
                        .font(.system(
                            size: reading.unit == "°" ? (secondary ? 20 : 28) : (secondary ? 13 : 15),
                            weight: reading.unit == "°" ? .semibold : .medium
                        ))
                        .monospacedDigit()
                }
            }
            if let label {
                HStack(spacing: tint == nil ? 0 : 5) {
                    if let tint {
                        Circle().fill(tint).frame(width: 6, height: 6)
                    }
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.panelSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([label, value].compactMap { $0 }.joined(separator: " "))
    }
}

private struct SideFact: View {
    let label: String
    let value: String?

    var body: some View {
        if let value {
            VStack(alignment: .trailing, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.panelSecondary)
                Text(value)
                    .font(.system(size: 13))
                    .monospacedDigit()
            }
            .multilineTextAlignment(.trailing)
        }
    }
}

private struct TimeAxis: View {
    var body: some View {
        HStack {
            Text("10 min ago")
            Spacer()
            Text("now")
        }
        .font(.system(size: 11))
        .foregroundStyle(Color.panelSecondary)
    }
}

private struct CoreBars: View {
    let title: String
    let loads: [Double]
    let columns: Int
    @ViewState private var hovered: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.panelSecondary)
                .frame(width: 70, alignment: .leading)
            // Every row splits the width into the same number of columns, so two efficiency
            // cores and eight performance cores read at the same scale; unused columns stay empty.
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<max(columns, loads.count), id: \.self) { i in
                    Group {
                        if i < loads.count {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 1).fill(Color.primary.opacity(0.09))
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.accentColor)
                                    .frame(height: max(1, 20 * loads[i]))
                            }
                            .onHover { inside in
                                if inside { hovered = i } else if hovered == i { hovered = nil }
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    // Drawn by hand: the panel never activates the app, so system tooltips from .help() don't appear.
                    .overlay(alignment: .top) {
                        if hovered == i, i < loads.count {
                            Text(MetricFormatter.format(loads[i], for: .cpu))
                                .font(.system(size: 11).monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                .fixedSize()
                                .offset(y: -22)
                                .allowsHitTesting(false)
                        }
                    }
                    .zIndex(hovered == i ? 1 : 0)
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
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Color.panelSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UpdateRow: View {
    let update: AvailableUpdate
    let currentVersion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text("Nadi \(update.version) is out. ").fontWeight(.semibold)
             + Text("You have \(currentVersion).").fontWeight(.regular))
                .font(.system(size: 12))
            HStack(spacing: 6) {
                Button("Download") { NSWorkspace.shared.open(update.downloadURL) }
                    .buttonStyle(.bordered)
                Button("Release notes") { NSWorkspace.shared.open(update.pageURL) }
                    .buttonStyle(.bordered)
            }
            .font(.system(size: 11))
            .padding(.top, 7)
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Color.primary.opacity(0.11).frame(height: 0.5)
        }
    }
}

private struct KeepAwakeRow: View {
    let keepAwake: KeepAwake

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text("Keep awake with lid closed")
                    .font(.system(size: 13))
                Spacer(minLength: 8)
                Toggle(
                    "Keep awake with lid closed",
                    isOn: Binding(
                        get: { keepAwake.isEnabled },
                        set: { value in Task { await keepAwake.setEnabled(value) } }
                    )
                )
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(keepAwake.isBusy)
            }
            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.panelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var note: String? {
        if let error = keepAwake.error { return "Could not change it: \(error)" }
        if keepAwake.isEnabled { return "Sleep is off, on battery too. Don't carry the Mac in a bag like this." }
        if !keepAwake.isAuthorized { return "The first time, macOS asks for your password." }
        return nil
    }
}

private struct PanelFooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary.opacity(0.75))
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
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
