import AppKit

/// Notices when any app starts dragging files, using global mouse monitors and the drag pasteboard.
@MainActor
final class DragWatcher {
    /// Called on every drag event while files are being dragged.
    var onUpdate: (([URL], NSEvent.ModifierFlags, NSPoint) -> Void)?
    var onEnded: (() -> Void)?

    private var monitors: [Any] = []
    private var changeCountAtMouseDown = 0
    private(set) var draggedFiles: [URL] = []

    func start() {
        guard monitors.isEmpty else { return }
        let add = { (mask: NSEvent.EventTypeMask, handler: @escaping @MainActor (NSEvent) -> Void) in
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
                MainActor.assumeIsolated { handler(event) }
            }) {
                self.monitors.append(monitor)
            }
        }
        add(.leftMouseDown) { [weak self] _ in
            self?.changeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
            self?.draggedFiles = []
        }
        add(.leftMouseDragged) { [weak self] event in self?.handleDrag(event) }
        add(.leftMouseUp) { [weak self] _ in self?.finish() }
    }

    private func handleDrag(_ event: NSEvent) {
        if draggedFiles.isEmpty {
            // A new drag session bumps the drag pasteboard's change count.
            let pasteboard = NSPasteboard(name: .drag)
            guard pasteboard.changeCount != changeCountAtMouseDown else { return }
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL] ?? []
            guard !urls.isEmpty else { return }
            draggedFiles = urls
        }
        onUpdate?(draggedFiles, event.modifierFlags, NSEvent.mouseLocation)
    }

    private func finish() {
        guard !draggedFiles.isEmpty else { return }
        draggedFiles = []
        onEnded?()
    }
}
