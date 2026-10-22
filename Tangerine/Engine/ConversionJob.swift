import Foundation
import UniformTypeIdentifiers

struct ConversionJob: Sendable {
    let input: URL
    let outputType: UTType
    let outputDirectory: URL
    /// 0...1, used by lossy formats.
    var quality: Double = 0.85
}
