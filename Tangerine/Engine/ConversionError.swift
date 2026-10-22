import Foundation
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case unreadableInput(URL)
    case unsupportedConversion(from: UTType, to: UTType)
    case writeFailed(URL)
    case passwordProtected(URL)
    case emptyDocument(URL)
    case noText(URL)

    var errorDescription: String? {
        switch self {
        case .unreadableInput(let url):
            String(localized: "Can't read \(url.lastPathComponent).")
        case .unsupportedConversion(let from, let to):
            String(localized: "Converting \(from.localizedDescription ?? from.identifier) to \(to.localizedDescription ?? to.identifier) isn't supported.")
        case .writeFailed(let url):
            String(localized: "Couldn't write \(url.lastPathComponent).")
        case .passwordProtected(let url):
            String(localized: "\(url.lastPathComponent) is password protected.")
        case .emptyDocument(let url):
            String(localized: "\(url.lastPathComponent) has no pages.")
        case .noText(let url):
            String(localized: "\(url.lastPathComponent) has no selectable text (it may be a scan).")
        }
    }
}
