import AppKit
import NadiCore
import NadiSensors
import SwiftUI

/// Renders the panel content to a PNG so its layout can be checked without opening the menu bar.
@MainActor
enum PanelSnapshot {
    static func write(to path: String, dark: Bool) async {
        let store = LiveStore()
        let sampler = Sampler(sensors: .system())
        await sampler.setDetailed(true)
        for i in 0..<12 {
            store.ingest(await sampler.sample())
            if i < 11 { try? await Task.sleep(for: .seconds(1)) }
        }
        let content = PanelSections(store: store)
            .padding(14)
            .frame(width: PanelView.width)
            .background(dark ? Color(white: 0.16) : Color(white: 0.95))
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.cgImage else {
            print("render failed")
            return
        }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")

        // The menu bar strip too, drawn in the label color on a plain background.
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        let items = MetricID.menuBarDefaults.map { MenuBarRenderer.Item(metric: $0, store: store, temperatureUnit: .celsius) }
        let strip = MenuBarRenderer().image(for: items, appearance: appearance, scale: 2)
        let stripPath = path.replacingOccurrences(of: ".png", with: "-menubar.png")
        if let cg = strip.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let canvas = NSImage(size: NSSize(width: strip.size.width + 16, height: strip.size.height))
            canvas.lockFocus()
            (dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.95, alpha: 1)).setFill()
            NSRect(origin: .zero, size: canvas.size).fill()
            appearance.performAsCurrentDrawingAppearance {
                if strip.isTemplate {
                    // Template images are black; tint with the label color the way the menu bar does.
                    NSColor.labelColor.setFill()
                    NSRect(x: 8, y: 0, width: strip.size.width, height: strip.size.height).fill()
                    NSImage(cgImage: cg, size: strip.size).draw(in: NSRect(x: 8, y: 0, width: strip.size.width, height: strip.size.height),
                                                                from: .zero, operation: .destinationIn, fraction: 1)
                } else {
                    strip.draw(at: NSPoint(x: 8, y: 0), from: .zero, operation: .sourceOver, fraction: 1)
                }
            }
            canvas.unlockFocus()
            if let tiff = canvas.tiffRepresentation, let out = NSBitmapImageRep(data: tiff) {
                try? out.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: stripPath))
                print("wrote \(stripPath)")
            }
        }
    }
}
