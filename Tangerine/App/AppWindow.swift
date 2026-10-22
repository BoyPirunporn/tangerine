import AppKit

enum AppWindow {
    static let title = "Tangerine"

    /// An app without a Dock icon can't always take focus from the app in front, so also order the
    /// window to the front directly. Without this it can open hidden behind other apps' windows.
    @MainActor
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.filter { $0.title == title }.forEach { $0.orderFrontRegardless() }
    }
}
