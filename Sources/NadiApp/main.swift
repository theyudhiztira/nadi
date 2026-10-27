import AppKit
import NadiCore
import NadiSensors

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = LiveStore()
    private let sampler = Sampler(sensors: .system())
    private var statusItem: StatusItemController?
    private var sampling: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController(store: store)
        sampling = Task { [sampler, store] in
            await sampler.run(into: store)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        sampling?.cancel()
    }
}

// `Nadi --dump [count]` prints snapshots to stdout instead of starting the menu bar app.
if let index = CommandLine.arguments.firstIndex(of: "--dump") {
    let count = CommandLine.arguments.dropFirst(index + 1).first.flatMap(Int.init) ?? 5
    await SnapshotDump.run(count: count)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Info.plist sets LSUIElement; this also hides the Dock icon when run as a bare binary.
app.setActivationPolicy(.accessory)
app.run()
