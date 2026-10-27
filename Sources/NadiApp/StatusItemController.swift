import AppKit
import NadiCore

@MainActor
final class StatusItemController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let renderer = MenuBarRenderer()
    private let store: LiveStore
    private var metrics: [MetricID] = MetricID.menuBarDefaults
    private var temperatureUnit: TemperatureUnit = .celsius
    private var lastRendered: [MenuBarRenderer.Item] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var appearanceName: NSAppearance.Name?

    init(store: LiveStore) {
        self.store = store
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Nadi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        item.button?.imagePosition = .imageOnly
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
