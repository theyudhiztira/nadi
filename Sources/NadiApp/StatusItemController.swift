import AppKit
import SwiftUI
import NadiCore

@MainActor
final class StatusItemController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let renderer = MenuBarRenderer()
    private let store: LiveStore
    private let panelStore = LiveStore()
    private let sampler: Sampler
    private let keepAwake: KeepAwake
    private let updateChecker: UpdateChecker
    private let loginItem = LoginItem()
    private var panel: StatusPanel?
    private var outsideClickMonitor: Any?
    private var metrics: [MetricID] = MetricID.menuBarDefaults
    private var temperatureUnit: TemperatureUnit = .celsius
    private var lastRendered: [MenuBarRenderer.Item] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var appearanceName: NSAppearance.Name?

    init(store: LiveStore, sampler: Sampler, keepAwake: KeepAwake, updateChecker: UpdateChecker) {
        self.store = store
        self.sampler = sampler
        self.keepAwake = keepAwake
        self.updateChecker = updateChecker
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        render()
        observe()
        // The pre-rendered bitmap uses green for charging, so redraw on light/dark switches.
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
        // Build the panel before a click can pay for SwiftUI's first layout.
        DispatchQueue.main.async { [weak self] in self?.preparePanel() }
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true { closePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let buttonWindow = item.button?.window, let screen = buttonWindow.screen ?? NSScreen.main, let panel else { return }
        panelStore.mirror(store)
        panel.setFrame(panelFrame(buttonWindow: buttonWindow, screen: screen), display: true)
        loginItem.refresh()
        Task { await keepAwake.refresh() }
        panel.makeKeyAndOrderFront(nil)
        item.button?.highlight(true)

        Task { await sampler.setDetailed(true) }
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
        Task { await sampler.setDetailed(false) }
    }

    private func makePanel() -> StatusPanel {
        let panel = StatusPanel(rootView: makePanelView())
        panel.onCancel = { [weak self] in self?.closePanel() }
        return panel
    }

    private func preparePanel() {
        guard panel == nil else { return }
        let panel = makePanel()
        self.panel = panel
        if let screen = item.button?.window?.screen ?? NSScreen.main {
            panel.setFrame(panelFrame(buttonWindow: item.button?.window, screen: screen), display: false)
        }
        panelStore.mirror(store)
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func panelFrame(buttonWindow: NSWindow?, screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let height = min(760, visible.height - 12)
        let buttonMidX = buttonWindow?.frame.midX ?? visible.midX
        let x = min(max(buttonMidX - PanelView.width / 2, visible.minX + 6), visible.maxX - PanelView.width - 6)
        let y = (buttonWindow?.frame.minY ?? visible.maxY) - 4 - height
        return NSRect(x: x, y: y, width: PanelView.width, height: height)
    }

    private func makePanelView() -> PanelView {
        PanelView(
            store: panelStore,
            loginItem: loginItem,
            keepAwake: keepAwake,
            updateChecker: updateChecker,
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func observe() {
        withObservationTracking {
            _ = store.latest
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.panel?.isVisible == true, let latest = self.store.latest {
                    self.panelStore.ingest(latest)
                }
                self.render()
                self.observe()
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
        button.setAccessibilityLabel(items.map(\.accessibilityText).joined(separator: ", "))
    }
}
