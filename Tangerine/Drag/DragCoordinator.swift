import AppKit

/// Wires the drag watcher to the radial menu according to the trigger mode.
@MainActor
final class DragCoordinator {
    private let watcher = DragWatcher()
    private let panel = DropPanelController()
    private let queue: QueueViewModel
    private lazy var hotKey = HotKey { [weak self] in self?.shortcutPressed() }

    init(queue: QueueViewModel) {
        self.queue = queue
    }

    func start() {
        watcher.onUpdate = { [weak self] urls, modifiers, point in
            guard TriggerMode.current.shouldShow(modifiers: modifiers) else { return }
            self?.present(urls, at: point)
        }
        watcher.onEnded = { [weak self] in self?.panel.hideSoon() }
        watcher.start()
        hotKey.register()
    }

    private func shortcutPressed() {
        guard TriggerMode.current == .shortcut, !watcher.draggedFiles.isEmpty else { return }
        present(watcher.draggedFiles, at: NSEvent.mouseLocation)
    }

    private func present(_ urls: [URL], at point: NSPoint) {
        guard !panel.isVisible else { return }
        let formats = QueueViewModel.ordered(queue.registry.outputs(forFiles: urls))
        guard !formats.isEmpty else { return }
        panel.show(urls: urls, formats: formats, near: point) { [queue] urls, type in
            queue.add(urls, as: type)
        }
    }
}
