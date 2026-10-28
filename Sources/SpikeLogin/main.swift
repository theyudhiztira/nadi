// Phase 0 spike: can an ad-hoc signed bundle use SMAppService.mainApp and post a notification?
import AppKit
import ServiceManagement
// Older SDKs (CI's macos-15 image) don't mark UNNotificationSettings Sendable.
@preconcurrency import UserNotifications

func log(_ line: String) {
    print(line)
    fflush(stdout)
}

func describe(_ status: SMAppService.Status) -> String {
    switch status {
    case .notRegistered: "notRegistered"
    case .enabled: "enabled"
    case .requiresApproval: "requiresApproval"
    case .notFound: "notFound"
    @unknown default: "unknown(\(status.rawValue))"
    }
}

func describe(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: "notDetermined"
    case .denied: "denied"
    case .authorized: "authorized"
    case .provisional: "provisional"
    @unknown default: "unknown(\(status.rawValue))"
    }
}

func describe(_ error: Error) -> String {
    let ns = error as NSError
    return "\(ns.domain) code=\(ns.code) \(ns.localizedDescription)"
}

@MainActor
func run() async {
    let unregister = CommandLine.arguments.contains("--unregister")
    log("bundle id: \(Bundle.main.bundleIdentifier ?? "nil")")
    log("bundle path: \(Bundle.main.bundlePath)")

    let service = SMAppService.mainApp
    log("SMAppService.mainApp status before: \(describe(service.status))")
    do {
        if unregister {
            try await service.unregister()
            log("unregister: ok")
        } else {
            try service.register()
            log("register: ok")
        }
    } catch {
        log("\(unregister ? "unregister" : "register") error: \(describe(error))")
    }
    log("SMAppService.mainApp status after: \(describe(service.status))")
    if unregister { exit(0) }

    let center = UNUserNotificationCenter.current()
    log("notification auth before: \(describe(await center.notificationSettings().authorizationStatus))")
    do {
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        log("requestAuthorization granted: \(granted)")
    } catch {
        log("requestAuthorization error: \(describe(error))")
    }
    log("notification auth after: \(describe(await center.notificationSettings().authorizationStatus))")

    let content = UNMutableNotificationContent()
    content.title = "Nadi spike"
    content.body = "Notification posted from an ad-hoc signed bundle."
    do {
        try await center.add(UNNotificationRequest(identifier: "spike", content: content, trigger: nil))
        log("notification add: ok")
    } catch {
        log("notification add error: \(describe(error))")
    }
    // Let the notification reach Notification Center before exiting.
    try? await Task.sleep(for: .seconds(2))
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { await run() }
app.run()
