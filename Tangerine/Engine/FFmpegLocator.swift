import Foundation

/// Finds an ffmpeg the user installed (we don't bundle one: see IMPLEMENT.md, Phase 7).
enum FFmpegLocator {
    private static let candidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/opt/local/bin/ffmpeg"]

    /// `TANGERINE_FFMPEG` overrides the search, for developers and tests.
    static var url: URL? {
        let custom = ProcessInfo.processInfo.environment["TANGERINE_FFMPEG"].map { [$0] } ?? []
        return (custom + candidates)
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    static var isAvailable: Bool { url != nil }
}
