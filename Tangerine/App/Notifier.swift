import AppKit
import UserNotifications

/// What to tell the user once the queue finishes a run.
struct BatchSummary: Equatable {
    let message: String
    /// Files to select in Finder when the notification is clicked.
    let reveal: [URL]

    init?(_ states: [QueueItem.State]) {
        var done: [URL] = []
        var failed = 0
        for state in states {
            switch state {
            case .done(let url): done.append(url)
            case .failed: failed += 1
            default: break
            }
        }
        guard !done.isEmpty || failed > 0 else { return nil }

        var parts: [String] = []
        if done.count == 1 {
            parts.append(String(localized: "Converted \(done[0].lastPathComponent)"))
        } else if done.count > 1 {
            parts.append(String(localized: "Converted \(done.count) files"))
        }
        if failed > 0 {
            parts.append(String(localized: "\(failed) failed"))
        }
        message = parts.joined(separator: " · ")
        reveal = done
    }
}

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    func setUp() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Stays quiet while Tangerine's own window is in front: the queue already shows the result.
    func notify(_ states: [QueueItem.State]) {
        guard !NSApp.isActive, let summary = BatchSummary(states) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tangerine"
        content.body = summary.message
        content.userInfo = ["paths": summary.reveal.map(\.path)]
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let paths = response.notification.request.content.userInfo["paths"] as? [String] ?? []
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
        }
    }
}
