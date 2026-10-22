import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Extracts the text of each page (with fonts, where PDFKit reports them) into a DOCX.
/// Layout, images and tables are not reconstructed.
struct PDFToDocxConverter: Converter {
    let supportedInputs: Set<UTType> = [.pdf]
    let outputs: Set<UTType> = [WordFormats.docx]

    func convert(_ job: ConversionJob, progress: @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        progress(0)
        let url = try await Self.perform(job)
        progress(1)
        return url
    }

    @MainActor
    private static func perform(_ job: ConversionJob) async throws -> URL {
        let document = try PDFSupport.open(job.input)
        let text = NSMutableAttributedString()
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index)?.attributedString else { continue }
            if text.length > 0 { text.append(NSAttributedString(string: "\n\n")) }
            text.append(page)
            // PDFKit needs the main thread; let the UI run between batches of pages.
            if index % 10 == 9 { await Task.yield() }
        }
        guard !text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.noText(job.input)
        }
        return try SafeWrite.write(
            in: job.outputDirectory,
            finalURL: { OutputPath.uniqueURL(for: job.input, type: WordFormats.docx, in: job.outputDirectory) }
        ) { temp in
            try WordFormats.write(text, as: WordFormats.docx, to: temp)
        }
    }
}
