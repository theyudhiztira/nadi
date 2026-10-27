import AppKit
import NadiCore

@MainActor
final class StatusItemController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let renderer = MenuBarRenderer()
    private let store: LiveStore
    private let sampler: Sampler
    private var panel: StatusPanel?
    private var outsideClickMonitor: Any?
    private var metrics: [MetricID] = MetricID.menuBarDefaults
    private var temperatureUnit: TemperatureUnit = .celsius
    private var lastRendered: [MenuBarRenderer.Item] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var appearanceName: NSAppearance.Name?

    init(store: LiveStore, sampler: Sampler) {
        self.store = store
        self.sampler = sampler
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        render()
        observe()
        // The pre-rendered bitmap bakes in colors when a value is alerting, so redraw on light/dark switches.
        // KVO also fires on unrelated button updates, so compare the light/dark match before redrawing.
        appearanceName = item.button?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        appearanceObservation = item.button?.observe(\.effectiveAppearance) { [weak self] button, _ in
            Task { @MainActor in
                guard let self else { return }
                let name = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
                guard name != self.appearanceName else { return }
                self.appearanceName = name
                self.lastRendered = []
                self.render()
            }
        }
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true { closePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let buttonWindow = item.button?.window, let screen = buttonWindow.screen ?? NSScreen.main else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let visible = screen.visibleFrame
        let height = min(760, visible.height - 12)
        var x = buttonWindow.frame.midX - PanelView.width / 2
        x = min(max(x, visible.minX + 6), visible.maxX - PanelView.width - 6)
        panel.setFrame(NSRect(x: x, y: buttonWindow.frame.minY - 4 - height, width: PanelView.width, height: height), display: true)
        panel.makeKeyAndOrderFront(nil)
        item.button?.highlight(true)

        Task { await sampler.setProcessSampling(true) }
        // Global monitors only see clicks in other apps, which is exactly "outside the panel".
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        item.button?.highlight(false)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        Task { await sampler.setProcessSampling(false) }
    }

    private func makePanel() -> StatusPanel {
        let panel = StatusPanel(rootView: PanelView(store: store, onQuit: { NSApp.terminate(nil) }))
        panel.onCancel = { [weak self] in self?.closePanel() }
        return panel
    }

    private func observe() {
        withObservationTracking {
            _ = store.latest
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render()
                self?.observe()
            }
        }
    }

    private func render() {
        let items = metrics.map { MenuBarRenderer.Item(metric: $0, store: store, temperatureUnit: temperatureUnit) }
        guard items != lastRendered, let button = item.button else { return }
        lastRendered = items
        let scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.image(for: items, appearance: button.effectiveAppearance, scale: scale)
        // A fixed length avoids a menu bar relayout on every redraw; widths only change with the metric list.
        let length = image.size.width + 8
        if item.length != length { item.length = length }
        button.image = image
        button.setAccessibilityLabel(items.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
    }
}
