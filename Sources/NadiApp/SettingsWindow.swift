import AppKit
import NadiCore
import SwiftUI

@MainActor
enum SettingsWindowController {
    private static var window: NSWindow?

    static func show(settings: SettingsStore, loginItem: LoginItem, live: LiveStore) {
        loginItem.refresh()
        if window == nil {
            let host = NSHostingController(rootView: SettingsRootView(settings: settings, loginItem: loginItem, live: live))
            host.sizingOptions = []
            let window = NSWindow(contentViewController: host)
            window.title = "Nadi Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 760, height: 640))
            window.contentMinSize = NSSize(width: 760, height: 520)
            window.contentMaxSize = NSSize(width: 760, height: 1_000)
            window.center()
            window.setFrameAutosaveName("NadiSettings")
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsRootView: View {
    private static let selectionKey = "settings.sidebar.selection"
    let settings: SettingsStore
    let loginItem: LoginItem
    let live: LiveStore
    let initialPage: String
    let previewPage: String?
    @ViewState private var selection: String?

    init(settings: SettingsStore, loginItem: LoginItem, live: LiveStore, initialPage: String = "menubar",
         previewPage: String? = nil) {
        self.settings = settings
        self.loginItem = loginItem
        self.live = live
        self.initialPage = initialPage
        self.previewPage = previewPage
        let saved = UserDefaults.standard.string(forKey: Self.selectionKey)
        _selection = ViewState(initialValue: (saved == "general" || saved == "menubar") ? saved : initialPage)
    }

    var body: some View {
        let activePage = previewPage ?? selection ?? initialPage
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 6) {
                sidebarButton("Menu Bar", symbol: "menubar.rectangle", page: "menubar", selected: activePage == "menubar")
                sidebarButton("General", symbol: "gearshape", page: "general", selected: activePage == "general")
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationSplitViewColumnWidth(180)
            .background(Color.settingsSidebar)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    Text("Nadi Settings").font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .frame(height: 52)
                .overlay(alignment: .bottom) { Color.primary.opacity(0.08).frame(height: 0.5) }
                ScrollView {
                    SettingsDetailView(page: activePage,
                                       settings: settings, loginItem: loginItem, live: live)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                }
            }
            .background(Color.settingsContent)
        }
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 760, minHeight: 520)
        .onChange(of: selection) { _, next in
            if let next { UserDefaults.standard.set(next, forKey: Self.selectionKey) }
        }
        .background {
            Button("Close") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w")
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    private func sidebarButton(_ title: String, symbol: String, page: String, selected: Bool) -> some View {
        Button {
            selection = page
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 18, alignment: .center)
                Text(title)
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsDetailView: View {
    let page: String
    let settings: SettingsStore
    let loginItem: LoginItem
    let live: LiveStore
    var snapshotMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(page == "general" ? "General" : "Menu Bar")
                .font(.system(size: 20, weight: .semibold))
                .padding(.bottom, 0)
            if page == "general" {
                GeneralSettingsPage(loginItem: loginItem)
            } else {
                MenuBarSettingsPage(settings: settings, live: live, snapshotMode: snapshotMode)
            }
        }
    }
}

private struct MenuBarSettingsPage: View {
    let settings: SettingsStore
    let live: LiveStore
    var snapshotMode = false
    @ViewState private var selected: MetricID?

    private var shown: [MetricID] { settings.settings.menuBarMetrics }
    private var missing: [MetricID] { MetricID.allCases.filter { !shown.contains($0) } }

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Preview") {
                SettingsCardRow {
                    ZStack(alignment: .leading) {
                        if shown.isEmpty {
                            Image(nsImage: ApplicationIcon.image)
                                .resizable()
                                .frame(width: 18, height: 18)
                                .padding(.trailing, 8)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            MenuBarPreview(live: live, metrics: shown, unit: settings.settings.temperatureUnit)
                                .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .leading)
                    .background(Color.settingsMenuBar, in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityLabel(shown.isEmpty ? "Nadi app icon" : "Menu bar preview")
                }
            }
            SettingsCard(title: "Shown in the menu bar", aside: shown.isEmpty ? nil : "Drag to reorder, or select a row and press ⌘↑ or ⌘↓") {
                if shown.isEmpty {
                    SettingsCardRow {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nothing is shown in the menu bar")
                                Text("Nadi shows its icon in the menu bar instead. Add a metric from Not shown below.")
                                    .font(.system(size: 11)).foregroundStyle(Color.panelSecondary)
                            }
                        } icon: {
                            Image(systemName: "menubar.rectangle").foregroundStyle(Color.accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                } else if snapshotMode {
                    ForEach(Array(shown.enumerated()), id: \.element) { index, metric in
                        SettingsCardRow(separator: index > 0) {
                            metricRow(metric, shown: true) { }
                        }
                    }
                } else {
                    List(selection: $selected) {
                        ForEach(shown, id: \.self) { metric in
                            metricRow(metric, shown: true) { remove(metric) }
                                .tag(metric)
                                .contextMenu {
                                    Button("Move to Top") { moveToTop(metric) }.disabled(shown.first == metric)
                                    Button("Move to Bottom") { moveToBottom(metric) }.disabled(shown.last == metric)
                                    Divider()
                                    Button("Remove") { remove(metric) }
                                }
                                .listRowSeparatorTint(Color.settingsSeparator)
                                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                                .listRowBackground(Color.settingsCard)
                        }
                        .onMove(perform: move)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 44)
                    .frame(height: CGFloat(shown.count) * 44)
                }
            }
            SettingsCard(title: "Readings") {
                HStack(spacing: 10) {
                    Image(systemName: "clock").foregroundStyle(Color.accentColor)
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Refresh every").font(.system(size: 13))
                        Text("How often the menu bar values update.")
                            .font(.system(size: 11)).foregroundStyle(Color.panelSecondary)
                    }
                    Spacer()
                    Slider(value: intervalBinding, in: 0.5...5, step: 0.5).frame(width: 170)
                    Text("\(settings.settings.interval, specifier: "%.1f") s").monospacedDigit().frame(width: 42, alignment: .trailing)
                }
                .settingsCardRow()
                HStack {
                    Image(systemName: "thermometer").foregroundStyle(Color.accentColor)
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    Text("Temperature").font(.system(size: 13))
                    Spacer()
                    Picker("Temperature", selection: unitBinding) {
                        Text("Celsius").tag(TemperatureUnit.celsius)
                        Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .settingsCardRow(separator: true)
            }
            SettingsCard(title: "Not shown") {
                if missing.isEmpty {
                    SettingsCardRow { Text("Every metric is in the menu bar.").foregroundStyle(Color.panelSecondary) }
                } else {
                    ForEach(Array(missing.enumerated()), id: \.offset) { index, metric in
                        SettingsCardRow(separator: index > 0) {
                            metricRow(metric, shown: false) {
                                settings.update { $0.menuBarMetrics.append(metric) }
                            }
                        }
                    }
                }
            }
        }
        .onDeleteCommand { if let selected { remove(selected) } }
        .onMoveCommand { direction in
            switch direction {
            case .up: moveSelected(-1)
            case .down: moveSelected(1)
            default: break
            }
        }
        .background {
            Group {
                Button("Move Up") { moveSelected(-1) }.keyboardShortcut(.upArrow, modifiers: .command)
                Button("Move Down") { moveSelected(1) }.keyboardShortcut(.downArrow, modifiers: .command)
            }.opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
        }
    }

    private func metricRow(_ metric: MetricID, shown: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            if shown {
                Image(systemName: "line.3.horizontal").foregroundStyle(Color.panelSecondary).frame(width: 14).accessibilityHidden(true)
            }
            Text(metric.settingsToken).font(.system(size: 10, weight: .medium))
                .frame(width: 46, height: 18).background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.settingsName).font(.system(size: 13))
                if metric.settingsDescription != metric.settingsName {
                    Text(metric.settingsDescription).font(.system(size: 11)).foregroundStyle(Color.panelSecondary)
                }
            }
            Spacer(minLength: 4)
            Text(metric.settingsUnit(settings.settings.temperatureUnit)).font(.system(size: 11)).foregroundStyle(Color.panelSecondary)
            Button(action: action) {
                Image(systemName: shown ? "minus.circle" : "plus.circle").foregroundStyle(Color.panelSecondary).frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(shown ? "Remove \(metric.settingsName)" : "Add \(metric.settingsName)")
            .accessibilityLabel("\(shown ? "Remove" : "Add") \(metric.settingsName)")
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.settingsName), \(metric.settingsDescription), \(metric.settingsUnit(settings.settings.temperatureUnit))")
    }

    private var intervalBinding: Binding<Double> {
        Binding(get: { settings.settings.interval }, set: { value in settings.update { $0.interval = value } })
    }

    private var unitBinding: Binding<TemperatureUnit> {
        Binding(get: { settings.settings.temperatureUnit }, set: { value in settings.update { $0.temperatureUnit = value } })
    }

    private func remove(_ metric: MetricID) {
        settings.update { $0.menuBarMetrics.removeAll { $0 == metric } }
        if selected == metric { selected = nil }
    }

    private func move(from source: IndexSet, to destination: Int) {
        settings.update { $0.menuBarMetrics.move(fromOffsets: source, toOffset: destination) }
    }

    private func moveSelected(_ offset: Int) {
        guard let selected, let index = shown.firstIndex(of: selected), shown.indices.contains(index + offset) else { return }
        settings.update { $0.menuBarMetrics.swapAt(index, index + offset) }
    }

    private func moveToTop(_ metric: MetricID) {
        settings.update { list in guard let index = list.menuBarMetrics.firstIndex(of: metric) else { return }; list.menuBarMetrics.insert(list.menuBarMetrics.remove(at: index), at: 0) }
    }

    private func moveToBottom(_ metric: MetricID) {
        settings.update { list in guard let index = list.menuBarMetrics.firstIndex(of: metric) else { return }; list.menuBarMetrics.append(list.menuBarMetrics.remove(at: index)) }
    }
}

private struct GeneralSettingsPage: View {
    let loginItem: LoginItem

    var body: some View {
        SettingsCard {
            HStack(spacing: 10) {
                Image(systemName: "power").foregroundStyle(Color.accentColor)
                    .frame(width: 26, height: 26).background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open at login").font(.system(size: 13))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.panelSecondary)
                }
                Spacer()
                Toggle("Open at login", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
                    .toggleStyle(.switch).labelsHidden().disabled(!loginItem.isAvailable || loginItem.needsApproval)
            }
            .settingsCardRow()
            HStack {
                Text("Version")
                    .font(.system(size: 13))
                Spacer()
                // Selectable so a bug report can paste it.
                Text(Self.version)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(Color.panelSecondary)
                    .textSelection(.enabled)
            }
            .settingsCardRow(separator: true)
            if loginItem.needsApproval {
                HStack {
                    Label("Disabled in Login Items.", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11)).foregroundStyle(Color.settingsWarning)
                    Spacer()
                    Button("Login Items…") { loginItem.openLoginItemsSettings() }
                }
                .settingsCardRow(separator: true)
            } else if let error = loginItem.error {
                Label("Could not change it: \(error)", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(Color.settingsWarning)
                    .settingsCardRow(separator: true)
            }
        }
    }

    private var subtitle: String {
        if !loginItem.isAvailable { return "Requires Nadi.app." }
        return "Opens Nadi when you log in to this Mac."
    }

    /// "v0.0.1 (1)" from Info.plist. A bare binary outside Nadi.app has no Info.plist.
    private static let version: String = {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "Dev build" }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "v\(short) (\($0))" } ?? "v\(short)"
    }()
}

private struct SettingsCard<Content: View>: View {
    let title: String?
    let aside: String?
    let content: Content

    init(title: String? = nil, aside: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.aside = aside
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 8)
                    if let aside {
                        Text(aside).font(.system(size: 11)).foregroundStyle(Color.panelSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.settingsCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).stroke(Color.settingsCardEdge, lineWidth: 0.5)
        }
    }
}

private struct SettingsCardRow<Content: View>: View {
    let separator: Bool
    let content: Content

    init(separator: Bool = false, @ViewBuilder content: () -> Content) {
        self.separator = separator
        self.content = content()
    }

    var body: some View {
        content
            .settingsCardRow(separator: separator)
    }
}

private extension View {
    func settingsCardRow(separator: Bool = false) -> some View {
        padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .overlay(alignment: .top) {
                if separator {
                    Color.settingsSeparator.frame(height: 0.5).padding(.horizontal, 14)
                }
            }
    }
}

extension Color {
    static let settingsSidebar = settingsColor("SettingsSidebar", light: 0xE9E9EB, dark: 0x2A2A2C)
    static let settingsContent = settingsColor("SettingsContent", light: 0xF2F2F2, dark: 0x262628)
    static let settingsCard = settingsColor("SettingsCard", light: 0xFFFFFF, dark: 0x2F2F31)
    static let settingsMenuBar = settingsColor("SettingsMenuBar", light: 0xE3E5E8, dark: 0x1E1F22)
    static let settingsCardEdge = settingsAlphaColor("SettingsCardEdge", light: .black, dark: .white, lightAlpha: 0.07, darkAlpha: 0.06)
    static let settingsSeparator = settingsAlphaColor("SettingsSeparator", light: .black, dark: .white, lightAlpha: 0.08, darkAlpha: 0.08)

    private static func settingsColor(_ name: String, light: UInt32, dark: UInt32) -> Color {
        Color(NSColor(name: NSColor.Name(name), dynamicProvider: { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }))
    }

    private static func settingsAlphaColor(
        _ name: String,
        light: NSColor,
        dark: NSColor,
        lightAlpha: CGFloat,
        darkAlpha: CGFloat
    ) -> Color {
        Color(NSColor(name: NSColor.Name(name), dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return (isDark ? dark : light).withAlphaComponent(isDark ? darkAlpha : lightAlpha)
        }))
    }

    static let settingsWarning = Color(NSColor(
        name: NSColor.Name("NadiSettingsWarning"),
        dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(red: 232 / 255, green: 180 / 255, blue: 76 / 255, alpha: 1)
            }
            return NSColor(red: 138 / 255, green: 90 / 255, blue: 0, alpha: 1)
        }
    ))
}

private struct MenuBarPreview: View {
    let live: LiveStore
    let metrics: [MetricID]
    let unit: TemperatureUnit

    var body: some View {
        let _ = live.latest
        let items = metrics.map { MenuBarRenderer.Item(metric: $0, store: live, temperatureUnit: unit) }
        PreviewRepresentable(items: items)
            .accessibilityLabel(items.map(\.accessibilityText).joined(separator: ", "))
    }
}

@MainActor
enum ApplicationIcon {
    static var image: NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }
}

private struct PreviewRepresentable: NSViewRepresentable {
    let items: [MenuBarRenderer.Item]

    func makeNSView(context: Context) -> PreviewStrip {
        PreviewStrip(items: items)
    }

    func updateNSView(_ view: PreviewStrip, context: Context) {
        view.items = items
    }
}

private final class PreviewStrip: NSView {
    private let renderer = MenuBarRenderer()
    private let imageView = NSImageView()
    var items: [MenuBarRenderer.Item] = [] { didSet { rebuild() } }

    convenience init(items: [MenuBarRenderer.Item]) {
        self.init(frame: .zero)
        self.items = items
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("PreviewStrip is code-only") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuild()
    }

    private func rebuild() {
        imageView.contentTintColor = .labelColor
        imageView.image = renderer.image(
            for: items,
            appearance: effectiveAppearance,
            scale: window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        )
    }
}

extension MetricID {
    var settingsName: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .cpuTemperature: "CPU temperature"
        case .power: "Power"
        case .gpu: "GPU"
        case .gpuTemperature: "GPU temperature"
        case .fan: "Fan speed"
        case .cpuPower: "CPU power"
        case .gpuPower: "GPU power"
        case .networkIn: "Network down"
        case .networkOut: "Network up"
        case .diskRead: "Disk read"
        case .diskWrite: "Disk write"
        case .network: "Network, both directions"
        }
    }

    var settingsDescription: String {
        switch self {
        case .cpu: "Processor usage"
        case .memory: "Memory usage"
        case .cpuTemperature: "CPU package temperature"
        case .power: "Combined system power draw"
        case .gpu: "Graphics processor usage"
        case .gpuTemperature: "GPU temperature"
        case .fan: "Fan speed"
        case .cpuPower: "Power used by the processor"
        case .gpuPower: "Power used by the graphics processor"
        case .networkIn: "Download speed only"
        case .networkOut: "Upload speed only"
        case .diskRead: "Disk read throughput"
        case .diskWrite: "Disk write throughput"
        case .network: "Upload and download together"
        }
    }

    var settingsToken: String {
        switch self {
        case .power: "Use"
        case .network: "↑ ↓"
        default: label
        }
    }

    func settingsUnit(_ unit: TemperatureUnit) -> String {
        switch self {
        case .cpu, .memory, .gpu: "%"
        case .cpuTemperature, .gpuTemperature: unit == .celsius ? "°C" : "°F"
        case .power, .cpuPower, .gpuPower: "W"
        case .fan: "RPM"
        case .networkIn, .networkOut, .network, .diskRead, .diskWrite: "bytes/s"
        }
    }
}
