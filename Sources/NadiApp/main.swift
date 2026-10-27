import AppKit
import NadiCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = Nadi.displayName

        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Nadi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu

        statusItem = item
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Info.plist sets LSUIElement; this also hides the Dock icon when run as a bare binary.
app.setActivationPolicy(.accessory)
app.run()
