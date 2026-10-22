import Foundation

enum SafeWrite {
    /// Runs `body` against a hidden temp path in `directory`, then moves the result to `finalURL()`.
    /// The final name is chosen after writing, and the temp item is removed on any failure or
    /// cancellation, so a half-written file never appears and an existing file is never replaced.
    static func write(
        in directory: URL,
        finalURL: () -> URL,
        body: (URL) throws -> Void
    ) throws -> URL {
        let temp = directory.appendingPathComponent(".tangerine-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temp) }
        try body(temp)
        try Task.checkCancellation()
        let final = finalURL()
        do {
            try FileManager.default.moveItem(at: temp, to: final)
        } catch {
            throw ConversionError.writeFailed(final)
        }
        return final
    }
}
