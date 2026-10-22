import Foundation
import UniformTypeIdentifiers

enum OutputPath {
    static func fileExtension(for type: UTType) -> String {
        type == .jpeg ? "jpg" : (type.preferredFilenameExtension ?? "out")
    }

    /// `name.ext`, or `name (1).ext`, `name (2).ext`… so existing files are never overwritten.
    static func uniqueURL(for input: URL, type: UTType, in directory: URL) -> URL {
        uniqueURL(named: input.deletingPathExtension().lastPathComponent,
                  pathExtension: fileExtension(for: type), in: directory)
    }

    /// Same, for outputs that are not named after an input (folders pass `nil`).
    static func uniqueURL(named base: String, pathExtension: String?, in directory: URL) -> URL {
        func candidate(_ name: String) -> URL {
            let url = directory.appendingPathComponent(name)
            return pathExtension.map { url.appendingPathExtension($0) } ?? url
        }
        var url = candidate(base)
        var n = 1
        while FileManager.default.fileExists(atPath: url.path) {
            url = candidate("\(base) (\(n))")
            n += 1
        }
        return url
    }
}
