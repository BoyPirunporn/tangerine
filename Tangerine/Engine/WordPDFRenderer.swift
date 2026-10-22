import AppKit

/// Lays text out on A4 pages and prints it to a PDF file through TextKit,
/// which handles pagination, tables and inline images.
@MainActor
enum WordPDFRenderer {
    private static let paper = NSSize(width: 595.28, height: 841.89) // A4, points
    private static let margin: CGFloat = 56.7 // 2 cm

    static func render(_ text: NSAttributedString, to url: URL) throws {
        let contentWidth = paper.width - 2 * margin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: paper.height))
        // Always lay out and print as light mode, whatever the system appearance is.
        textView.appearance = NSAppearance(named: .aqua)
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(text)

        if let container = textView.textContainer, let layoutManager = textView.layoutManager {
            layoutManager.ensureLayout(for: container)
            textView.setFrameSize(NSSize(width: contentWidth, height: max(layoutManager.usedRect(for: container).height, 1)))
        }

        let info = NSPrintInfo(dictionary: [
            .jobDisposition: NSPrintInfo.JobDisposition.save,
            .jobSavingURL: url,
        ])
        info.paperSize = paper
        info.topMargin = margin
        info.bottomMargin = margin
        info.leftMargin = margin
        info.rightMargin = margin
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false

        let operation = NSPrintOperation(view: textView, printInfo: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else { throw ConversionError.writeFailed(url) }
    }
}
