import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// True when macOS started us as a login item rather than the user opening the app.
    private static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// One queue shared by the main window and the radial menu.
    let queue = QueueViewModel()
    private let notifier = Notifier()
    private lazy var coordinator = DragCoordinator(queue: queue)

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.launchedAtLogin {
            // Start quietly in the menu bar; the window opens from the menu.
            DispatchQueue.main.async { NSApp.windows.filter { $0.title == AppWindow.title }.forEach { $0.close() } }
        } else {
            // The window is created just after launch, so wait a moment before raising it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { AppWindow.bringToFront() }
        }
        notifier.setUp()
        queue.onBatchFinished = { [notifier] states in notifier.notify(states) }
        coordinator.start()
    }
}

@main
struct TangerineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window(AppWindow.title, id: "main") {
            ContentView(model: delegate.queue)
        }
        MenuBarExtra("Tangerine", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarMenu()
        }
    }
}
