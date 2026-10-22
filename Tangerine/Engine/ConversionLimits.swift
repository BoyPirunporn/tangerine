import Foundation
import UniformTypeIdentifiers

/// Honest notes about what a conversion can't preserve, shown to the user before and after converting.
enum ConversionLimits {
    static func note(from input: UTType?, to output: UTType) -> String? {
        guard let input else { return nil }
        if input.conforms(to: .pdf), output == WordFormats.docx {
            return String(localized: "Text only: layout, images and tables are not kept.")
        }
        if input == WordFormats.docx, output == .pdf {
            return String(localized: "Fonts, tables or images may look slightly different.")
        }
        if input == .gif, output != .gif {
            return String(localized: "Animated GIFs keep only the first frame.")
        }
        return nil
    }
}
