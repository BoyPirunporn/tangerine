import AppKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// One page → `name.png`. Several pages → a folder `name/` holding `name-001.png`, `name-002.png`…
struct PDFToImageConverter: Converter {
    let supportedInputs: Set<UTType> = [.pdf]
    let outputs: Set<UTType> = [.png, .jpeg]

    private static let dpi = 150.0
    private static let maxPixels = 8000.0

    func convert(_ job: ConversionJob, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        let document = try PDFSupport.open(job.input)
        let count = document.pageCount
        let base = job.input.deletingPathExtension().lastPathComponent
        progress(0)

        let result: URL
        if count == 1 {
            result = try SafeWrite.write(
                in: job.outputDirectory,
                finalURL: { OutputPath.uniqueURL(for: job.input, type: job.outputType, in: job.outputDirectory) }
            ) { temp in
                try render(document, pageIndex: 0, to: temp, job: job)
            }
        } else {
            result = try SafeWrite.write(
                in: job.outputDirectory,
                finalURL: { OutputPath.uniqueURL(named: base, pathExtension: nil, in: job.outputDirectory) }
            ) { temp in
                try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
                for index in 0..<count {
                    try Task.checkCancellation()
                    let name = PDFSupport.pageName(base, page: index + 1, of: count)
                    let file = temp.appendingPathComponent(name)
                        .appendingPathExtension(OutputPath.fileExtension(for: job.outputType))
                    try render(document, pageIndex: index, to: file, job: job)
                    progress(Double(index + 1) / Double(count))
                }
            }
        }
        progress(1)
        return result
    }

    private func render(_ document: PDFDocument, pageIndex: Int, to url: URL, job: ConversionJob) throws {
        guard let page = document.page(at: pageIndex) else { throw ConversionError.unreadableInput(job.input) }
        var size = page.bounds(for: .mediaBox).size
        if page.rotation % 180 != 0 { size = CGSize(width: size.height, height: size.width) }
        let scale = min(Self.dpi / 72, Self.maxPixels / max(size.width, size.height, 1))
        let pixels = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let thumbnail = page.thumbnail(of: pixels, for: .mediaBox)
        guard let image = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL, job.outputType.identifier as CFString, 1, nil)
        else { throw ConversionError.writeFailed(url) }
        let options = [kCGImageDestinationLossyCompressionQuality: job.quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.writeFailed(url) }
    }
}
