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
        await sampler.setProcessSampling(true)
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
    }
}
