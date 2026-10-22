import Foundation
import UniformTypeIdentifiers

struct DocxToPDFConverter: Converter {
    let supportedInputs: Set<UTType> = [WordFormats.docx]
    let outputs: Set<UTType> = [.pdf]

    func convert(_ job: ConversionJob, progress: @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        progress(0)
        let url = try await Self.perform(job)
        progress(1)
        return url
    }

    @MainActor
    private static func perform(_ job: ConversionJob) throws -> URL {
        let text = try WordFormats.read(job.input, as: WordFormats.docx)
        return try SafeWrite.write(
            in: job.outputDirectory,
            finalURL: { OutputPath.uniqueURL(for: job.input, type: .pdf, in: job.outputDirectory) }
        ) { temp in
            try WordPDFRenderer.render(text, to: temp)
        }
    }
}
