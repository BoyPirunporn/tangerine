import Foundation
import UniformTypeIdentifiers

/// DOCX, HTML and plain text, converted between each other through an attributed string.
struct TextDocumentConverter: Converter {
    private static let formats: Set<UTType> = [WordFormats.docx, .html, .plainText]

    let supportedInputs = formats
    let outputs = formats

    /// Exact matches only: many file types (source code, CSV…) conform to plain text,
    /// and we don't want to offer to turn all of those into Word documents.
    func canConvert(from input: UTType, to output: UTType) -> Bool {
        input != output && Self.formats.contains(input) && Self.formats.contains(output)
    }

    func convert(_ job: ConversionJob, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        progress(0)
        let inputType = try job.input.resourceValues(forKeys: [.contentTypeKey]).contentType
        guard let inputType else { throw ConversionError.unreadableInput(job.input) }
        let url = try await Self.perform(job, inputType: inputType)
        progress(1)
        return url
    }

    @MainActor
    private static func perform(_ job: ConversionJob, inputType: UTType) throws -> URL {
        let text = try WordFormats.read(job.input, as: inputType)
        return try SafeWrite.write(
            in: job.outputDirectory,
            finalURL: { OutputPath.uniqueURL(for: job.input, type: job.outputType, in: job.outputDirectory) }
        ) { temp in
            try WordFormats.write(text, as: job.outputType, to: temp)
        }
    }
}
