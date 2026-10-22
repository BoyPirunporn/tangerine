import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Raster ↔ raster. Animated inputs (GIF, multi-page TIFF) keep their first frame only.
struct ImageConverter: Converter {
    let supportedInputs = ImageFormats.readable
    let outputs = ImageFormats.writable

    func convert(_ job: ConversionJob, progress: @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        progress(0)

        guard let source = CGImageSourceCreateWithURL(job.input as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw ConversionError.unreadableInput(job.input) }

        let finalURL = try SafeWrite.write(
            in: job.outputDirectory,
            finalURL: { OutputPath.uniqueURL(for: job.input, type: job.outputType, in: job.outputDirectory) }
        ) { temp in
            guard let destination = CGImageDestinationCreateWithURL(
                temp as CFURL, job.outputType.identifier as CFString, 1, nil
            ) else { throw ConversionError.writeFailed(temp) }

            var options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: job.quality]
            if job.outputType == .jpeg, hasAlpha(image) {
                // JPEG has no alpha: flatten onto white instead of letting transparency turn black.
                if let orientation = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])?[kCGImagePropertyOrientation] {
                    options[kCGImagePropertyOrientation] = orientation
                }
                CGImageDestinationAddImage(destination, flattenedOnWhite(image), options as CFDictionary)
            } else {
                // Copies metadata (EXIF, orientation, DPI) from the source.
                CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
            }
            guard CGImageDestinationFinalize(destination) else { throw ConversionError.writeFailed(temp) }
        }
        progress(1)
        return finalURL
    }

    private func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }

    private func flattenedOnWhite(_ image: CGImage) -> CGImage {
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return image }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage() ?? image
    }
}
