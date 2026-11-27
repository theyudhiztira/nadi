import Foundation
import NadiCore
import Observation

@MainActor
@Observable
final class KeepAwake {
    private(set) var isEnabled = false
    private(set) var isAuthorized = false
    private(set) var isBusy = false
    private(set) var error: String?

    private let ownedKey = "keepAwakeOwned"

    func refresh() async {
        let (status, output) = await run("/usr/bin/pmset", arguments: ["-g"])
        isEnabled = status == 0 && KeepAwakeRule.sleepDisabled(pmsetOutput: output) == true
        // `sudo -l` reports what an admin may run, not whether it needs a password, so check for Nadi's own rule.
        isAuthorized = FileManager.default.fileExists(atPath: KeepAwakeRule.sudoersPath)
    }

    func setEnabled(_ on: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        error = nil

        let arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"]
        var result = await run("/usr/bin/sudo", arguments: arguments)
        var failure = result.status == 0 ? nil : message(result)

        if result.status != 0 && result.output.contains("password is required"),
           let script = KeepAwakeRule.installScript(user: NSUserName()) {
            let command = "do shell script \(KeepAwakeRule.appleScriptLiteral(script)) with administrator privileges"
            let installation = await run("/usr/bin/osascript", arguments: ["-e", command])
            if installation.status == 0 {
                isAuthorized = true
                result = await run("/usr/bin/sudo", arguments: arguments)
                failure = result.status == 0 ? nil : message(result)
            } else if installation.output.contains("-128") {
                failure = nil
            } else {
                failure = message(installation)
            }
        }

        if result.status == 0 {
            UserDefaults.standard.set(on, forKey: ownedKey)
        } else {
            error = failure
        }
        await refresh()
    }

    func recoverOnLaunch() async {
        guard UserDefaults.standard.bool(forKey: ownedKey) else { return }
        let (status, output) = await run("/usr/bin/pmset", arguments: ["-g"])
        guard status == 0, let disabled = KeepAwakeRule.sleepDisabled(pmsetOutput: output) else { return }
        guard disabled else {
            UserDefaults.standard.set(false, forKey: ownedKey)
            return
        }
        let (releaseStatus, _) = await run(
            "/usr/bin/sudo",
            arguments: ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"]
        )
        if releaseStatus == 0 {
            UserDefaults.standard.set(false, forKey: ownedKey)
        }
        await refresh()
    }

    func releaseOnQuit() {
        guard UserDefaults.standard.bool(forKey: ownedKey) else { return }
        Self.runSynchronously("/usr/bin/sudo", arguments: ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"])
        UserDefaults.standard.set(false, forKey: ownedKey)
    }

    private func run(_ executable: String, arguments: [String]) async -> (status: Int32, output: String) {
        await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
            } catch {
                return (-1, error.localizedDescription)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }.value
    }

    private func message(_ result: (status: Int32, output: String)) -> String {
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? "Command failed (status \(result.status))." : output
    }

    private static func runSynchronously(_ executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
        } catch {}
    }
}
