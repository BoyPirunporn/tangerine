import AppKit
import PDFKit

enum PDFSupport {
    /// Opens a PDF, rejecting unreadable, locked and empty files.
    static func open(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else { throw ConversionError.unreadableInput(url) }
        if document.isLocked { throw ConversionError.passwordProtected(url) }
        guard document.pageCount > 0 else { throw ConversionError.emptyDocument(url) }
        return document
    }

    /// One PDF page sized to the image. Multi-frame images contribute their first frame.
    static func page(forImageAt url: URL) -> PDFPage? {
        NSImage(contentsOf: url).flatMap { PDFPage(image: $0) }
    }

    /// `base-001`, `base-002`… zero-padded so files sort in page order.
    static func pageName(_ base: String, page: Int, of count: Int) -> String {
        let width = max(3, String(count).count)
        return "\(base)-" + String(format: "%0\(width)d", page)
    }
}
