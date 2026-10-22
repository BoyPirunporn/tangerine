import Foundation
import UniformTypeIdentifiers

protocol Converter: Sendable {
    var supportedInputs: Set<UTType> { get }
    var outputs: Set<UTType> { get }

    /// Writes a new file into `job.outputDirectory` and returns its URL.
    /// Must honour task cancellation and never leave partial output behind.
    func convert(_ job: ConversionJob, progress: @Sendable (Double) -> Void) async throws -> URL

    /// Whether this converter handles `input` → `output`. Override to be stricter than the default.
    func canConvert(from input: UTType, to output: UTType) -> Bool
}

extension Converter {
    func canConvert(from input: UTType, to output: UTType) -> Bool {
        input != output
            && outputs.contains(output)
            && supportedInputs.contains { input.conforms(to: $0) }
    }
}
