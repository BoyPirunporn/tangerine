import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// One queue shared by the main window and the radial menu.
    let queue = QueueViewModel()
    private let notifier = Notifier()
    private lazy var coordinator = DragCoordinator(queue: queue)

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.setUp()
        queue.onBatchFinished = { [notifier] states in notifier.notify(states) }
        coordinator.start()
    }
}

@main
struct TangerineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Tangerine", id: "main") {
            ContentView(model: delegate.queue)
        }
        MenuBarExtra("Tangerine", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarMenu()
        }
    }
}
