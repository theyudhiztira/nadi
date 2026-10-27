import AppKit
import NadiCore

/// Draws the selected metrics into one status bar image: label, bar history, current value.
@MainActor
final class MenuBarRenderer {
    struct Item: Hashable {
        var label: String
        var value: String
        /// Bar heights 0...1, oldest first; nil draws no bar.
        var bars: [Double?]
        var alerting: Bool
        /// Widest value this metric can show, reserved so the item never jitters.
        var widestValue: String
    }

    static let barCount = 20
    private static let barWidth: CGFloat = 1
    private static let barGap: CGFloat = 0.5
    private static let graphHeight: CGFloat = 13
    private static let labelGap: CGFloat = 3
    private static let valueGap: CGFloat = 3
    private static let itemGap: CGFloat = 9

    private let labelFont = NSFont.systemFont(ofSize: 10, weight: .medium)
    private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

    /// Template images follow the menu bar's own text color. Only an alerting value needs real color.
    func image(for items: [Item], appearance: NSAppearance, scale: CGFloat) -> NSImage {
        let height = NSStatusBar.system.thickness
        let layout = items.map { item in
            (item: item,
             labelWidth: ceil(width(item.label, font: labelFont)),
             valueWidth: ceil(width(item.widestValue, font: valueFont)))
        }
        let graphWidth = CGFloat(Self.barCount) * (Self.barWidth + Self.barGap) - Self.barGap
        let totalWidth = layout.reduce(0) { sum, entry in
            sum + entry.labelWidth + Self.labelGap + graphWidth + Self.valueGap + entry.valueWidth
        } + Self.itemGap * CGFloat(max(items.count - 1, 0))

        let anyAlerting = items.contains { $0.alerting }
        let size = NSSize(width: max(totalWidth, 1), height: height)
        // A pre-rendered bitmap: a drawing-handler image would re-run this code on every status item snapshot.
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return NSImage(size: size) }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        appearance.performAsCurrentDrawingAppearance {
            var x: CGFloat = 0
            for entry in layout {
                let base: NSColor = anyAlerting ? .labelColor : .black
                let color: NSColor = entry.item.alerting ? .systemRed : base

                let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: color.withAlphaComponent(0.8)]
                let labelSize = (entry.item.label as NSString).size(withAttributes: labelAttrs)
                (entry.item.label as NSString).draw(at: NSPoint(x: x, y: (height - labelSize.height) / 2), withAttributes: labelAttrs)
                x += entry.labelWidth + Self.labelGap

                let graphY = (height - Self.graphHeight) / 2
                color.withAlphaComponent(0.18).setFill()
                NSRect(x: x, y: graphY, width: graphWidth, height: Self.graphHeight).fill()
                color.setFill()
                let bars = entry.item.bars.suffix(Self.barCount)
                // Right-align so the newest sample sits next to the value.
                var barX = x + CGFloat(Self.barCount - bars.count) * (Self.barWidth + Self.barGap)
                for bar in bars {
                    if let bar, bar > 0 {
                        let h = max(1, (Self.graphHeight * bar).rounded())
                        NSRect(x: barX, y: graphY, width: Self.barWidth, height: h).fill()
                    }
                    barX += Self.barWidth + Self.barGap
                }
                x += graphWidth + Self.valueGap

                let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: color]
                let valueSize = (entry.item.value as NSString).size(withAttributes: valueAttrs)
                (entry.item.value as NSString).draw(
                    at: NSPoint(x: x + entry.valueWidth - valueSize.width, y: (height - valueSize.height) / 2),
                    withAttributes: valueAttrs
                )
                x += entry.valueWidth + Self.itemGap
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        image.isTemplate = !anyAlerting
        return image
    }

    private func width(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}

extension MenuBarRenderer.Item {
    @MainActor
    init(metric: MetricID, store: LiveStore, temperatureUnit: TemperatureUnit) {
        let latest = store.latest
        let value = latest?.value(metric)
        let samples = store.recent(metric, count: MenuBarRenderer.barCount)
        let bars = GraphScale.fractions(samples, for: metric, adapterRatingWatts: latest?.power?.adapterRatingWatts)
        // Quantize so tiny changes that move no pixel do not trigger a redraw.
        let quantized = bars.map { $0.map { ($0 * 26).rounded() / 26 } }
        self.init(
            label: metric.label,
            value: MetricFormatter.format(value, for: metric, temperatureUnit: temperatureUnit),
            bars: quantized,
            alerting: metric.isAlerting(value),
            widestValue: metric.widestValue
        )
    }
}

extension MetricID {
    var widestValue: String {
        switch self {
        case .cpu, .memory: "100%"
        case .cpuTemperature: "100°"
        case .power: "100W"
        }
    }
}
