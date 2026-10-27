import AppKit
import NadiCore

/// Draws the selected metrics into one status bar image. Each slot is a label plus a bar history (CPU),
/// a line history (RAM, temperatures), a bare value (power), or two stacked values (network).
@MainActor
final class MenuBarRenderer {
    enum Graph: Hashable {
        case none
        /// Heights 0...1, oldest first; nil leaves a gap.
        case bars([Double?])
        case line([Double?])
        /// Two small lines of text replace both the graph and the value.
        case stacked(top: String, bottom: String, widest: String)
    }

    enum Tint: Hashable {
        case normal
        case alert
        case good
        case caution

        var color: NSColor? {
            switch self {
            case .normal: nil
            case .alert: .systemRed
            case .good: .systemGreen
            case .caution: .systemYellow
            }
        }
    }

    struct Item: Hashable {
        var label: String
        /// Widest label this slot can show, reserved so the slot never changes width.
        var widestLabel: String
        var value: String
        var widestValue: String
        var graph: Graph
        var tint: Tint
    }

    static let sampleCount = 20
    private static let barWidth: CGFloat = 1
    private static let barGap: CGFloat = 0.5
    private static let graphWidth = CGFloat(sampleCount) * (barWidth + barGap) - barGap
    private static let graphHeight: CGFloat = 13
    private static let labelGap: CGFloat = 3
    private static let valueGap: CGFloat = 3
    private static let itemGap: CGFloat = 9

    private let labelFont = NSFont.systemFont(ofSize: 10, weight: .medium)
    private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private let stackedFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)

    /// A template image follows the menu bar's own text color; only a tinted slot needs real colors.
    func image(for items: [Item], appearance: NSAppearance, scale: CGFloat) -> NSImage {
        let height = NSStatusBar.system.thickness
        let widths = items.map(slotWidths)
        let totalWidth = widths.reduce(0) { $0 + $1.total } + Self.itemGap * CGFloat(max(items.count - 1, 0))
        let size = NSSize(width: max(ceil(totalWidth), 1), height: height)

        // A pre-rendered bitmap: a drawing-handler image would re-run this code on every status item snapshot.
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return NSImage(size: size) }
        rep.size = size

        let template = items.allSatisfy { $0.tint == .normal }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        appearance.performAsCurrentDrawingAppearance {
            var x: CGFloat = 0
            for (item, w) in zip(items, widths) {
                let base: NSColor = template ? .black : .labelColor
                let color = item.tint.color ?? base
                drawLabel(item.label, at: x, height: height, color: color.withAlphaComponent(0.8))
                x += w.label + Self.labelGap

                switch item.graph {
                case .none:
                    break
                case .bars(let samples):
                    drawBars(samples, at: x, height: height, color: color)
                    x += Self.graphWidth + Self.valueGap
                case .line(let samples):
                    drawLine(samples, at: x, height: height, color: color)
                    x += Self.graphWidth + Self.valueGap
                case .stacked(let top, let bottom, _):
                    drawStacked(top, bottom, at: x, width: w.value, height: height, color: color)
                }

                if case .stacked = item.graph {} else {
                    drawValue(item.value, rightEdge: x + w.value, height: height, color: color)
                }
                x += w.value + Self.itemGap
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        image.isTemplate = template
        return image
    }

    private func slotWidths(_ item: Item) -> (label: CGFloat, value: CGFloat, total: CGFloat) {
        let label = ceil(width(item.widestLabel, font: labelFont))
        let graph: CGFloat
        let value: CGFloat
        switch item.graph {
        case .none:
            graph = 0
            value = ceil(width(item.widestValue, font: valueFont))
        case .bars, .line:
            graph = Self.graphWidth + Self.valueGap
            value = ceil(width(item.widestValue, font: valueFont))
        case .stacked(_, _, let widest):
            graph = 0
            value = ceil(width(widest, font: stackedFont))
        }
        return (label, value, label + Self.labelGap + graph + value)
    }

    private func drawLabel(_ text: String, at x: CGFloat, height: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: x, y: (height - size.height) / 2), withAttributes: attrs)
    }

    private func drawValue(_ text: String, rightEdge: CGFloat, height: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: rightEdge - size.width, y: (height - size.height) / 2), withAttributes: attrs)
    }

    private func drawStacked(_ top: String, _ bottom: String, at x: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: stackedFont, .foregroundColor: color]
        let lineHeight = (top as NSString).size(withAttributes: attrs).height
        let gap: CGFloat = -1
        let blockTop = (height + 2 * lineHeight + gap) / 2
        for (i, text) in [top, bottom].enumerated() {
            let size = (text as NSString).size(withAttributes: attrs)
            let y = blockTop - CGFloat(i + 1) * lineHeight - CGFloat(i) * gap
            (text as NSString).draw(at: NSPoint(x: x + width - size.width, y: y), withAttributes: attrs)
        }
    }

    private func graphRect(at x: CGFloat, height: CGFloat) -> NSRect {
        NSRect(x: x, y: (height - Self.graphHeight) / 2, width: Self.graphWidth, height: Self.graphHeight)
    }

    private func drawBars(_ samples: [Double?], at x: CGFloat, height: CGFloat, color: NSColor) {
        let rect = graphRect(at: x, height: height)
        color.withAlphaComponent(0.18).setFill()
        rect.fill()
        color.setFill()
        let bars = samples.suffix(Self.sampleCount)
        // Right-align so the newest sample sits next to the value.
        var barX = rect.minX + CGFloat(Self.sampleCount - bars.count) * (Self.barWidth + Self.barGap)
        for bar in bars {
            if let bar, bar > 0 {
                NSRect(x: barX, y: rect.minY, width: Self.barWidth, height: max(1, (rect.height * bar).rounded())).fill()
            }
            barX += Self.barWidth + Self.barGap
        }
    }

    private func drawLine(_ samples: [Double?], at x: CGFloat, height: CGFloat, color: NSColor) {
        let rect = graphRect(at: x, height: height)
        color.withAlphaComponent(0.18).setFill()
        rect.fill()
        let points = samples.suffix(Self.sampleCount)
        let step = rect.width / CGFloat(Self.sampleCount - 1)
        let path = NSBezierPath()
        path.lineWidth = 1.25
        path.lineJoinStyle = .round
        var penDown = false
        var px = rect.minX + CGFloat(Self.sampleCount - points.count) * step
        for value in points {
            if let value {
                // Inset by half the line width so 0 and 1 stay inside the track.
                let y = rect.minY + 0.75 + (rect.height - 1.5) * value
                if penDown { path.line(to: NSPoint(x: px, y: y)) } else { path.move(to: NSPoint(x: px, y: y)) }
                penDown = true
            } else {
                penDown = false
            }
            px += step
        }
        color.setStroke()
        path.stroke()
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
        let samples = GraphScale.fractions(
            store.recent(metric, count: MenuBarRenderer.sampleCount), for: metric,
            adapterRatingWatts: latest?.power?.adapterRatingWatts
        )
        // Quantize so changes too small to move a pixel do not trigger a redraw.
        let quantized = samples.map { $0.map { ($0 * 26).rounded() / 26 } }
        let formatted = MetricFormatter.format(value, for: metric, temperatureUnit: temperatureUnit)
        let tint: MenuBarRenderer.Tint = metric.isAlerting(value) ? .alert : .normal

        switch metric {
        case .power:
            self = Self.power(latest?.powerDisplay)
        case .network:
            let up = latest?.network.map { MetricFormatter.bytesPerSecond($0.outPerSecond) } ?? MetricFormatter.missing
            let down = latest?.network.map { MetricFormatter.bytesPerSecond($0.inPerSecond) } ?? MetricFormatter.missing
            self.init(label: "", widestLabel: "", value: "", widestValue: "",
                      graph: .stacked(top: "↑ \(up)", bottom: "↓ \(down)", widest: "↓ 999 KB/s"), tint: .normal)
        case .memory, .cpuTemperature, .gpuTemperature, .fan, .cpuPower, .gpuPower, .networkIn, .networkOut,
             .diskRead, .diskWrite:
            self.init(label: metric.label, widestLabel: metric.label, value: formatted,
                      widestValue: metric.widestValue, graph: .line(quantized), tint: tint)
        case .cpu, .gpu:
            self.init(label: metric.label, widestLabel: metric.label, value: formatted,
                      widestValue: metric.widestValue, graph: .bars(quantized), tint: tint)
        }
    }

    /// Battery charge watts while charging (green, or yellow when slow), whole-system draw otherwise (D21).
    private static func power(_ display: PowerDisplay?) -> Self {
        switch display {
        case .charging(let watts, let slow):
            Self(label: "Chg", widestLabel: "Chg", value: MetricFormatter.watts(watts), widestValue: "100W",
                 graph: .none, tint: slow ? .caution : .good)
        case .consuming(let watts):
            Self(label: "Use", widestLabel: "Chg", value: watts.map(MetricFormatter.watts) ?? MetricFormatter.missing,
                 widestValue: "100W", graph: .none, tint: .normal)
        case .none:
            Self(label: "Use", widestLabel: "Chg", value: MetricFormatter.missing, widestValue: "100W", graph: .none, tint: .normal)
        }
    }
}

extension MetricID {
    var widestValue: String {
        switch self {
        case .cpu, .memory, .gpu: "100%"
        case .cpuTemperature, .gpuTemperature: "100°"
        case .power, .cpuPower, .gpuPower: "100W"
        case .fan: "9.9k"
        case .networkIn, .networkOut, .diskRead, .diskWrite, .network: "999 KB/s"
        }
    }
}

extension MenuBarRenderer.Item {
    var accessibilityText: String {
        switch graph {
        case .stacked(let top, let bottom, _):
            "Network upload \(top.dropFirst(2)), download \(bottom.dropFirst(2))"
        default:
            switch tint {
            case .good: "Charging \(value)"
            case .caution: "Charging slowly \(value)"
            default: "\(label) \(value)"
            }
        }
    }
}
