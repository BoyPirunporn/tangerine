import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Operations that don't fit "one file, one target format": merging and splitting PDFs.
enum PDFTools {
    /// PDFs and images, in the order given, become one `Merged.pdf`.
    @concurrent
    static func merge(
        _ inputs: [URL],
        outputDirectory: URL,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        let merged = PDFDocument()
        for (index, input) in inputs.enumerated() {
            try Task.checkCancellation()
            let type = try? input.resourceValues(forKeys: [.contentTypeKey]).contentType
            if type?.conforms(to: .pdf) == true {
                let source = try PDFSupport.open(input)
                for pageIndex in 0..<source.pageCount {
                    guard let page = source.page(at: pageIndex)?.copy() as? PDFPage else {
                        throw ConversionError.unreadableInput(input)
                    }
                    merged.insert(page, at: merged.pageCount)
                }
            } else {
                guard let page = PDFSupport.page(forImageAt: input) else {
                    throw ConversionError.unreadableInput(input)
                }
                merged.insert(page, at: merged.pageCount)
            }
            progress(Double(index + 1) / Double(inputs.count))
        }
        return try SafeWrite.write(
            in: outputDirectory,
            finalURL: { OutputPath.uniqueURL(named: "Merged", pathExtension: "pdf", in: outputDirectory) }
        ) { temp in
            guard merged.write(to: temp) else { throw ConversionError.writeFailed(temp) }
        }
    }

    /// One PDF → a folder `name-pages/` with a single-page PDF per page.
    @concurrent
    static func split(
        _ input: URL,
        outputDirectory: URL,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        let source = try PDFSupport.open(input)
        let count = source.pageCount
        let base = input.deletingPathExtension().lastPathComponent
        return try SafeWrite.write(
            in: outputDirectory,
            finalURL: { OutputPath.uniqueURL(named: "\(base)-pages", pathExtension: nil, in: outputDirectory) }
        ) { temp in
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
            for index in 0..<count {
                try Task.checkCancellation()
                guard let page = source.page(at: index)?.copy() as? PDFPage else {
                    throw ConversionError.unreadableInput(input)
                }
                let single = PDFDocument()
                single.insert(page, at: 0)
                let file = temp
                    .appendingPathComponent(PDFSupport.pageName(base, page: index + 1, of: count))
                    .appendingPathExtension("pdf")
                guard single.write(to: file) else { throw ConversionError.writeFailed(file) }
                progress(Double(index + 1) / Double(count))
            }
        }
    }
}
