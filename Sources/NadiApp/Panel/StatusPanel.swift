import AppKit
import SwiftUI

/// Borderless panel that drops from the status item, like the system's own menu bar panels.
final class StatusPanel: NSPanel {
    var onCancel: (() -> Void)?
    private let hosting: NSHostingView<PanelView>

    init(rootView: PanelView) {
        hosting = NSHostingView(rootView: rootView)
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        // AppKit fixes the panel size; intrinsic measurement can trigger a full-tree layout.
        hosting.sizingOptions = []

        // The menu material is the one translucent surface in Nadi; it matches the system's menu bar panels.
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        contentView = background

        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
