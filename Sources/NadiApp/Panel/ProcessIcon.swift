import AppKit
import Darwin
import UniformTypeIdentifiers

@MainActor
enum ProcessIcon {
    private struct Key: Hashable {
        let pid: Int32
        let name: String
    }

    private static var cache: [Key: NSImage] = [:]
    private static let fallback = NSWorkspace.shared.icon(for: .unixExecutable)

    static func icon(for pid: Int32, name: String) -> NSImage {
        let key = Key(pid: pid, name: name)
        if let cached = cache[key] { return cached }

        let resolved = resolve(pid: pid)
        if cache.count >= 256 { cache.removeAll(keepingCapacity: true) }
        cache[key] = resolved
        return resolved
    }

    private static func resolve(pid: Int32) -> NSImage {
        if let appIcon = NSRunningApplication(processIdentifier: pid)?.icon {
            return appIcon
        }

        if let path = executablePath(for: pid) {
            let target = appBundlePath(for: path) ?? path
            return NSWorkspace.shared.icon(forFile: target)
        }

        return fallback
    }

    private static func executablePath(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    static func appBundlePath(for executablePath: String) -> String? {
        var url = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
        var appBundles: [String] = []
        while url.path != "/" {
            if url.pathExtension == "app" {
                appBundles.append(url.path(percentEncoded: false))
            }
            url.deleteLastPathComponent()
        }
        guard !appBundles.isEmpty else { return nil }
        // Helper bundles inside an app (e.g. Chrome Helper.app) often lack their own icon; prefer the
        // innermost .app that declares one, otherwise fall back to the outermost enclosing .app.
        for path in appBundles {
            if let info = Bundle(path: path)?.infoDictionary,
               info["CFBundleIconFile"] != nil || info["CFBundleIconName"] != nil || info["CFBundleIcons"] != nil {
                return path
            }
        }
        return appBundles.last
    }
}
