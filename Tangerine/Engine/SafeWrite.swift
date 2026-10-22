import Foundation

enum SafeWrite {
    /// Runs `body` against a hidden temp path in `directory`, then moves the result to `finalURL()`.
    /// The final name is chosen after writing, and the temp item is removed on any failure or
    /// cancellation, so a half-written file never appears and an existing file is never replaced.
    /// `pathExtension` is for writers that pick the file format from the extension.
    static func write(
        in directory: URL,
        pathExtension: String? = nil,
        finalURL: () -> URL,
        body: (URL) throws -> Void
    ) throws -> URL {
        let temp = tempURL(in: directory, pathExtension: pathExtension)
        defer { try? FileManager.default.removeItem(at: temp) }
        try body(temp)
        return try finish(temp, finalURL: finalURL)
    }

    static func write(
        in directory: URL,
        pathExtension: String? = nil,
        finalURL: () -> URL,
        body: (URL) async throws -> Void
    ) async throws -> URL {
        let temp = tempURL(in: directory, pathExtension: pathExtension)
        defer { try? FileManager.default.removeItem(at: temp) }
        try await body(temp)
        return try finish(temp, finalURL: finalURL)
    }

    private static func tempURL(in directory: URL, pathExtension: String?) -> URL {
        let url = directory.appendingPathComponent(".tangerine-\(UUID().uuidString)")
        return url.appendingPathExtension(pathExtension ?? "tmp")
    }

    private static func finish(_ temp: URL, finalURL: () -> URL) throws -> URL {
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
