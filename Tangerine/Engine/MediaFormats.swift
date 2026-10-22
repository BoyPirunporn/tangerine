import Foundation
import UniformTypeIdentifiers

enum MediaFormats {
    /// `.m4a` files report `com.apple.m4a-audio`, which conforms to `public.mpeg-4-audio`.
    static let m4a = UTType("com.apple.m4a-audio") ?? .mpeg4Audio
    static let flac = UTType("org.xiph.flac") ?? UTType(importedAs: "org.xiph.flac", conformingTo: .audio)
    static let mp4 = UTType.mpeg4Movie
    static let mov = UTType.quickTimeMovie

    /// Declared in Config/Info-extra.plist; `importedAs` keeps the identifier usable if the lookup fails.
    static let mkv = UTType("org.matroska.mkv") ?? UTType(importedAs: "org.matroska.mkv", conformingTo: .movie)

    static let audioInputs: Set<UTType> = [.mp3, .wav, m4a, flac, .aiff]
    /// What macOS can open and export natively.
    static let videoInputs: Set<UTType> = [mp4, mov]
    /// Everything ffmpeg can additionally read.
    static let allVideo: Set<UTType> = videoInputs.union([mkv])
}
