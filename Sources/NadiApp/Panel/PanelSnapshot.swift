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
        guard let pageURL = URL(string: "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.1"),
              let downloadURL = URL(string: "https://github.com/theyudhiztira/nadi/releases/download/v0.0.1/Nadi-0.0.1.zip") else { return }
        let update = AvailableUpdate(version: "0.2.0", pageURL: pageURL, downloadURL: downloadURL)
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        let content = VStack(spacing: 0) {
            PanelTopRows(update: update, currentVersion: "0.1.0", keepAwake: KeepAwake())
            PanelSections(store: store)
            PanelBottomRows(loginItem: LoginItem(), onQuit: {})
        }
        .frame(width: PanelView.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(dark ? Color(red: 44 / 255.0, green: 44 / 255.0, blue: 46 / 255.0) : Color(red: 236 / 255.0, green: 236 / 255.0, blue: 236 / 255.0))
        .environment(\.colorScheme, dark ? .dark : .light)
        let hostingView = NSHostingView(rootView: content)
        hostingView.appearance = appearance
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            print("render failed")
            return
        }
        bitmap.size = size
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        (dark
         ? NSColor(red: 44 / 255.0, green: 44 / 255.0, blue: 46 / 255.0, alpha: 1)
         : NSColor(red: 236 / 255.0, green: 236 / 255.0, blue: 236 / 255.0, alpha: 1)).setFill()
        NSRect(origin: .zero, size: size).fill()
        NSGraphicsContext.restoreGraphicsState()
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let image = bitmap.cgImage else {
            print("render failed")
            return
        }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")

        // The menu bar strip too, drawn in the label color on a plain background.
        let items = MetricID.menuBarDefaults.map { MenuBarRenderer.Item(metric: $0, store: store, temperatureUnit: .celsius) }
        let strip = MenuBarRenderer().image(for: items, appearance: appearance, scale: 2)
        let stripPath = URL(fileURLWithPath: path).deletingPathExtension().path(percentEncoded: false) + "-menubar.png"
        let canvas = NSImage(size: NSSize(width: strip.size.width + 16, height: strip.size.height))
        canvas.lockFocus()
        (dark
         ? NSColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1)
         : NSColor(red: 230 / 255.0, green: 230 / 255.0, blue: 232 / 255.0, alpha: 1)).setFill()
        NSRect(origin: .zero, size: canvas.size).fill()
        appearance.performAsCurrentDrawingAppearance {
            let rect = NSRect(x: 8, y: 0, width: strip.size.width, height: strip.size.height)
            if strip.isTemplate {
                // Template images are black; tint with the label color the way the menu bar does.
                if let mask = strip.cgImage(forProposedRect: nil, context: nil, hints: nil),
                   let context = NSGraphicsContext.current?.cgContext {
                    context.saveGState()
                    context.clip(to: rect, mask: mask)
                    NSColor.labelColor.setFill()
                    rect.fill()
                    context.restoreGState()
                }
            } else {
                strip.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            }
        }
        canvas.unlockFocus()
        if let tiff = canvas.tiffRepresentation, let out = NSBitmapImageRep(data: tiff) {
            try? out.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: stripPath))
            print("wrote \(stripPath)")
        }
    }
}
