import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// A floating panel that never takes focus, so the drag in progress keeps going underneath it.
@MainActor
final class DropPanelController {
    private static let log = Logger(subsystem: "com.tangerine.converter", category: "panel")
    private static let size = CGSize(width: RadialMenuView.size, height: RadialMenuView.size)

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    private var isHandlingDrop = false

    var isVisible: Bool { panel?.isVisible == true }

    func show(
        urls: [URL],
        formats: [UTType],
        near point: NSPoint,
        onChoose: @escaping ([URL], UTType) -> Void
    ) {
        hide()
        isHandlingDrop = false
        let panel = FloatingPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // the SwiftUI view draws its own soft shadow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: RadialMenuView(
            urls: urls,
            formats: formats,
            choose: { [weak self] urls, type in
                self?.dropReceived()
                onChoose(urls, type)
            },
            finished: { [weak self] in self?.hide() }
        ))
        panel.setFrame(frame(near: point), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        Self.log.info("show for \(urls.count) file(s)")
    }

    /// The global mouse-up that ends a drag can arrive before the panel's own drop callback,
    /// so hiding right away would remove the panel before it receives the files.
    func hideSoon() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self, !isHandlingDrop else { return }
            hide()
        }
    }

    private func dropReceived() {
        isHandlingDrop = true
        hideTask?.cancel()
    }

    func hide() {
        hideTask?.cancel()
        if panel != nil { Self.log.info("hide") }
        panel?.orderOut(nil)
        panel = nil
    }

    /// Centred on the cursor, kept fully on the screen the cursor is on.
    private func frame(near point: NSPoint) -> CGRect {
        var frame = CGRect(
            x: point.x - Self.size.width / 2,
            y: point.y - Self.size.height / 2,
            width: Self.size.width,
            height: Self.size.height
        )
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }
        return frame
    }
}
