import AppKit
import UniformTypeIdentifiers

/// Reading and writing text documents with AppKit's attributed-string importers.
/// These touch the text system (HTML import even uses WebKit), so they run on the main actor.
@MainActor
enum WordFormats {
    nonisolated static let docx = UTType("org.openxmlformats.wordprocessingml.document")
        ?? UTType(importedAs: "org.openxmlformats.wordprocessingml.document")

    private static func documentType(for type: UTType) -> NSAttributedString.DocumentType? {
        switch type {
        case docx: .officeOpenXML
        case .html: .html
        case .plainText: .plain
        default: nil
        }
    }

    static func read(_ url: URL, as type: UTType) throws -> NSAttributedString {
        guard let documentType = documentType(for: type) else { throw ConversionError.unreadableInput(url) }
        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: documentType]
        if documentType != .officeOpenXML {
            options[.characterEncoding] = String.Encoding.utf8.rawValue
        }
        do {
            return try NSAttributedString(url: url, options: options, documentAttributes: nil)
        } catch {
            throw ConversionError.unreadableInput(url)
        }
    }

    static func write(_ text: NSAttributedString, as type: UTType, to url: URL) throws {
        guard let documentType = documentType(for: type) else { throw ConversionError.writeFailed(url) }
        var attributes: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: documentType]
        if documentType != .officeOpenXML {
            attributes[.characterEncoding] = String.Encoding.utf8.rawValue
        }
        do {
            let data = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: attributes)
            try data.write(to: url)
        } catch {
            throw ConversionError.writeFailed(url)
        }
    }
}
