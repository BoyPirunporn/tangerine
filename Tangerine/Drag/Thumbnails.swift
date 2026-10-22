import AppKit
import QuickLookThumbnailing

enum Thumbnails {
    /// The Finder icon right away; replace it with a real preview when one is available.
    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func preview(for url: URL, side: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: CGSize(width: side, height: side),
            scale: 2, representationTypes: .thumbnail
        )
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        else { return nil }
        return NSImage(cgImage: representation.cgImage, size: CGSize(width: side, height: side))
    }
}
