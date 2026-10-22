import AppKit
import SwiftUI
import os

private let log = Logger(subsystem: "com.tangerine.converter", category: "drop")

/// Receives file drags through AppKit directly. SwiftUI's `dropDestination` never fired inside our
/// floating panel. Positions are reported y-down, in this view's coordinate space.
final class DropTargetView: NSView {
    var onMove: (CGPoint?) -> Void = { _ in }
    /// Return `false` to reject the drop.
    var onDrop: ([URL], CGPoint) -> Bool = { _, _ in false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func location(of sender: any NSDraggingInfo) -> CGPoint {
        let point = convert(sender.draggingLocation, from: nil)
        return CGPoint(x: point.x, y: bounds.height - point.y)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        log.info("draggingEntered")
        onMove(location(of: sender))
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        onMove(location(of: sender))
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        log.info("draggingExited")
        onMove(nil)
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        log.info("performDragOperation: \(urls.count) file(s)")
        guard !urls.isEmpty else { return false }
        return onDrop(urls, location(of: sender))
    }
}

struct DropTarget: NSViewRepresentable {
    let onMove: (CGPoint?) -> Void
    let onDrop: ([URL], CGPoint) -> Bool

    func makeNSView(context: Context) -> DropTargetView { DropTargetView() }

    func updateNSView(_ view: DropTargetView, context: Context) {
        view.onMove = onMove
        view.onDrop = onDrop
    }
}
