import Foundation
import UniformTypeIdentifiers

struct ConverterRegistry: Sendable {
    let converters: [any Converter]

    static let standard = ConverterRegistry(converters: [
        ImageConverter(), ImageToPDFConverter(), PDFToImageConverter(),
        DocxToPDFConverter(), PDFToDocxConverter(), TextDocumentConverter(),
    ])

    func converter(from input: UTType, to output: UTType) -> (any Converter)? {
        converters.first { $0.canConvert(from: input, to: output) }
    }

    var allOutputs: Set<UTType> {
        converters.reduce(into: Set<UTType>()) { $0.formUnion($1.outputs) }
    }

    func canRead(_ type: UTType) -> Bool {
        converters.contains { $0.supportedInputs.contains { type.conforms(to: $0) } }
    }

    /// Formats the given input type can be converted into.
    func outputs(for input: UTType) -> Set<UTType> {
        converters.reduce(into: Set<UTType>()) { result, converter in
            result.formUnion(converter.outputs.filter { converter.canConvert(from: input, to: $0) })
        }
    }

    /// Formats valid for every one of the given files; empty if any file can't be read.
    func outputs(forFiles urls: [URL]) -> Set<UTType> {
        var common: Set<UTType>?
        for url in urls {
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else { return [] }
            let formats = outputs(for: type)
            common = common.map { $0.intersection(formats) } ?? formats
        }
        return common ?? []
    }

    @concurrent
    func convert(
        _ job: ConversionJob,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        guard let inputType = try? job.input.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            throw ConversionError.unreadableInput(job.input)
        }
        guard let converter = converter(from: inputType, to: job.outputType) else {
            throw ConversionError.unsupportedConversion(from: inputType, to: job.outputType)
        }
        return try await converter.convert(job, progress: progress)
    }
}
