import Foundation
import Observation
import ServiceManagement

/// Opens Nadi.app at login through `SMAppService.mainApp`.
/// macOS owns the switch (System Settings, General, Login Items), so the state is read back from there, never stored here.
@MainActor
@Observable
final class LoginItem {
    private(set) var status: SMAppService.Status
    /// The last register or unregister failure, cleared by the next success.
    private(set) var error: String?

    /// A bare binary from `swift build` has no bundle for launchd to open.
    let isAvailable = Bundle.main.bundleURL.pathExtension == "app"

    private let service = SMAppService.mainApp

    init() {
        status = service.status
    }

    var isEnabled: Bool { status == .enabled }

    /// The user turned Nadi off in Login Items; only they can turn it back on there.
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() } else { try service.unregister() }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        refresh()
    }

    /// The user can change the switch in System Settings while Nadi runs, so read it again before showing it.
    func refresh() {
        status = service.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
