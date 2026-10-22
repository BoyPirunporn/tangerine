import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageFormats {
    /// `public.avif`, looked up by identifier so we don't depend on a newer SDK constant.
    static let avif = UTType("public.avif") ?? UTType(importedAs: "public.avif")

    static let readable: Set<UTType> = [.png, .jpeg, .heic, .webP, .tiff, .gif, .bmp, avif]

    /// Formats we want to write, limited to what ImageIO can actually encode on this Mac
    /// (WebP, for example, can be read but not written).
    static let writable: Set<UTType> = {
        let supported = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        let wanted: Set<UTType> = [.png, .jpeg, .heic, avif, .tiff, .gif, .bmp]
        return wanted.filter { supported.contains($0.identifier) }
    }()
}
