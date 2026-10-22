import Foundation
import PDFKit
import UniformTypeIdentifiers

struct ImageToPDFConverter: Converter {
    let supportedInputs = ImageFormats.readable
    let outputs: Set<UTType> = [.pdf]

    func convert(_ job: ConversionJob, progress: @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        progress(0)
        guard let page = PDFSupport.page(forImageAt: job.input) else {
            throw ConversionError.unreadableInput(job.input)
        }
        let document = PDFDocument()
        document.insert(page, at: 0)

        let finalURL = try SafeWrite.write(
            in: job.outputDirectory,
            finalURL: { OutputPath.uniqueURL(for: job.input, type: .pdf, in: job.outputDirectory) }
        ) { temp in
            guard document.write(to: temp) else { throw ConversionError.writeFailed(temp) }
        }
        progress(1)
        return finalURL
    }
}
