import AppKit
import NadiCore
import NadiSensors
import SwiftUI

@MainActor
enum SettingsSnapshot {
    static func write(to path: String, dark: Bool) async {
        let _ = NSApplication.shared
        let loginItem = LoginItem()
        loginItem.refresh()
        let live = LiveStore()
        let settings = makeStore()
        let sampler = Sampler(sensors: .system())
        await sampler.setDetailed(true)
        await sampler.setMenuBarMetrics(settings.settings.menuBarMetrics)
        for index in 0..<3 {
            live.ingest(await sampler.sample())
            if index < 2 { try? await Task.sleep(for: .seconds(1)) }
        }
        let base = URL(fileURLWithPath: path).deletingPathExtension()
        render(SettingsSnapshotRoot(page: "menubar", settings: settings, loginItem: loginItem, live: live),
               to: base.path + "-menubar.png",
               dark: dark)
        render(SettingsSnapshotRoot(page: "general", settings: settings, loginItem: loginItem, live: live),
               to: base.path + "-general.png",
               dark: dark)

        let empty = makeStore()
        empty.update { $0.menuBarMetrics = [] }
        render(SettingsSnapshotRoot(page: "menubar", settings: empty, loginItem: loginItem, live: live),
               to: base.path + "-empty.png",
               dark: dark)
    }

    private static func makeStore() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: "Nadi.SettingsRender.\(UUID().uuidString)")!)
    }

    private static func render<Content: View>(_ content: Content, to path: String, dark: Bool) {
        let size = NSSize(width: 760, height: 640)
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.layoutSubtreeIfNeeded()
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
        ) else { return }
        bitmap.size = size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

private struct SettingsSnapshotRoot: View {
    let page: String
    let settings: SettingsStore
    let loginItem: LoginItem
    let live: LiveStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                }
                .frame(width: 46, height: 12)
                .padding(.leading, 10)
                .frame(height: 52, alignment: .center)
                sidebarRow("Menu Bar", symbol: "menubar.rectangle", selected: page == "menubar")
                sidebarRow("General", symbol: "gearshape", selected: page == "general")
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(width: 180)
            .background(Color.settingsSidebar)
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 0.5)
            VStack(spacing: 0) {
                HStack {
                    Text("Nadi Settings").font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .frame(height: 52)
                .overlay(alignment: .bottom) { Color.primary.opacity(0.08).frame(height: 0.5) }
                ScrollView {
                    SettingsDetailView(page: page, settings: settings, loginItem: loginItem, live: live, snapshotMode: true)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                }
            }
            .background(Color.settingsContent)
        }
        .frame(width: 760, height: 640)
    }

    private func sidebarRow(_ title: String, symbol: String, selected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 18, alignment: .center)
            Text(title)
                .font(.system(size: 13, weight: selected ? .medium : .regular))
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 7))
    }
}
