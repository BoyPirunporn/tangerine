import SwiftUI
import os

struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage(TriggerMode.storageKey) private var trigger = TriggerMode.shift.rawValue
    @State private var launchAtLogin = LoginItem.isEnabled

    private static let log = Logger(subsystem: "com.tangerine.converter", category: "login")

    var body: some View {
        Button("Open Tangerine") {
            openWindow(id: "main")
            AppWindow.bringToFront()
        }
        Picker("Show format menu", selection: $trigger) {
            ForEach(TriggerMode.allCases, id: \.rawValue) { mode in
                Text(mode.title).tag(mode.rawValue)
            }
        }
        Toggle("Launch at login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, enabled in
                do {
                    try LoginItem.set(enabled)
                } catch {
                    Self.log.error("login item failed: \(error.localizedDescription)")
                    launchAtLogin = LoginItem.isEnabled
                }
            }
        if !FFmpegLocator.isAvailable {
            Divider()
            Text("MP3 and MKV need ffmpeg: brew install ffmpeg")
        }
        Divider()
        Button("Quit Tangerine") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
