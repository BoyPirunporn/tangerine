import AVFoundation
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

/// Runs against the ffmpeg installed on this Mac; skipped when there is none.
@Suite(.enabled(if: FFmpegLocator.isAvailable, "ffmpeg is not installed"))
struct RealFFmpegTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    private func convert(_ input: URL, to type: UTType, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> URL {
        try await ConverterRegistry.standard.convert(
            ConversionJob(input: input, outputType: type, outputDirectory: dir), progress: progress)
    }

    /// `tool` is looked up next to ffmpeg (ffprobe), or taken as a full path.
    private func run(_ tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = tool.hasPrefix("/")
            ? URL(fileURLWithPath: tool)
            : try #require(FFmpegLocator.url).deletingLastPathComponent().appendingPathComponent(tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /// "video", "audio"… of the streams in a file, according to ffprobe.
    private func streams(of url: URL) throws -> [String] {
        try run("ffprobe", ["-v", "error", "-show_entries", "stream=codec_type", "-of", "csv=p=0", url.path])
            .split(separator: "\n").map(String.init).sorted()
    }

    private func probedDuration(_ url: URL) throws -> Double {
        Double(try run("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", url.path])
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    // MARK: MP3

    @Test func wavToMp3() async throws {
        let wav = try TestMedia.makeWAV("tone.wav", in: dir)
        let mp3 = try await convert(wav, to: .mp3)
        #expect(mp3.lastPathComponent == "tone.mp3")
        #expect(try mp3.resourceValues(forKeys: [.contentTypeKey]).contentType == .mp3)
        #expect(abs(try TestMedia.duration(of: mp3) - 1) < 0.1)   // macOS itself can decode what we encoded
        #expect(try streams(of: mp3) == ["audio"])
    }

    @Test func qualityChangesTheMp3Size() async throws {
        let wav = try TestMedia.makeWAV("q.wav", seconds: 3, in: dir)
        func size(_ quality: Double) async throws -> Int {
            let output = try await ConverterRegistry.standard.convert(
                ConversionJob(input: wav, outputType: .mp3, outputDirectory: dir, quality: quality))
            return try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        }
        let best = try await size(1), smallest = try await size(0.1)
        #expect(best > smallest)
    }

    @Test func videoToMp3DropsThePicture() async throws {
        let mp4 = try await TestMedia.makeVideo("clip.mp4", withAudio: true, in: dir)
        let mp3 = try await convert(mp4, to: .mp3)
        #expect(try streams(of: mp3) == ["audio"])
        #expect(abs(try TestMedia.duration(of: mp3) - 1) < 0.1)
    }

    // MARK: MKV

    @Test func mp4ToMkvAndBackKeepsPictureAndSound() async throws {
        let mp4 = try await TestMedia.makeVideo("movie.mp4", withAudio: true, in: dir)
        let mkv = try await convert(mp4, to: MediaFormats.mkv)
        #expect(mkv.lastPathComponent == "movie.mkv")
        #expect(try mkv.resourceValues(forKeys: [.contentTypeKey]).contentType == MediaFormats.mkv)
        #expect(try streams(of: mkv) == ["audio", "video"])

        let back = try await convert(mkv, to: MediaFormats.mov)
        let asset = AVURLAsset(url: back)   // and macOS can now play it
        #expect(try await !asset.loadTracks(withMediaType: .video).isEmpty)
        #expect(try await !asset.loadTracks(withMediaType: .audio).isEmpty)
        #expect(abs(try probedDuration(back) - 1) < 0.2)
    }

    @Test func mkvToAudioFormats() async throws {
        let mp4 = try await TestMedia.makeVideo("src.mp4", withAudio: true, in: dir)
        let mkv = try await convert(mp4, to: MediaFormats.mkv)
        for type in [UTType.wav, MediaFormats.flac, MediaFormats.m4a, .mp3] {
            let audio = try await convert(mkv, to: type)
            #expect(try streams(of: audio) == ["audio"], "\(type.identifier)")
            #expect(abs(try probedDuration(audio) - 1) < 0.2, "\(type.identifier)")
        }
    }

    @Test func menuOffersMp3AndMkvOnceFFmpegIsThere() throws {
        let registry = ConverterRegistry.standard
        #expect(registry.outputs(for: MediaFormats.mkv) ==
                [MediaFormats.mp4, MediaFormats.mov, MediaFormats.m4a, .mp3, .wav, MediaFormats.flac])
        #expect(registry.outputs(for: .wav).contains(.mp3))
        #expect(registry.allOutputs.contains(MediaFormats.mkv))
    }

    // MARK: failure, progress, cancel

    @Test func corruptMkvReportsFFmpegsOwnMessage() async throws {
        let bad = dir.appendingPathComponent("bad.mkv")
        try Data("this is not matroska".utf8).write(to: bad)
        let error = await #expect(throws: ConversionError.self) { try await convert(bad, to: .mp3) }
        guard case .toolFailed(let detail)? = error else { Issue.record("got \(String(describing: error))"); return }
        #expect(!detail.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["bad.mkv"])
    }

    @Test func realProgressAndCancelOnALongClip() async throws {
        // 60 s of 720p, made by ffmpeg itself.
        let long = dir.appendingPathComponent("long.mkv")
        _ = try run("ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc2=size=1280x720:rate=30",
                               "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100", "-t", "60",
                               "-c:v", "h264_videotoolbox", "-b:v", "4M", "-c:a", "aac", long.path])
        try #require(FileManager.default.fileExists(atPath: long.path))

        let seen = Seen()
        let task = Task { try await convert(long, to: MediaFormats.mp4) { seen.add($0) } }
        try await seen.waitUntil { $0 > 0 && $0 < 1 }          // real progress arrives while it runs

        // Only this test's ffmpeg has long.mkv as its input. It must be running right now, which also
        // proves the check below can see it (otherwise "nothing found" would prove nothing).
        let ffmpegOnThisFile = "ffmpeg.*[-]i .*[/]long[.]mkv"
        #expect(!(try run("/usr/bin/pgrep", ["-f", ffmpegOnThisFile])).isEmpty, "expected ffmpeg to be running before the cancel")
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }

        try await Task.sleep(for: .milliseconds(500))
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(left == ["long.mkv"], "left behind: \(left)")
        let stray = try run("/usr/bin/pgrep", ["-fl", ffmpegOnThisFile])
        #expect(stray.isEmpty, "ffmpeg is still running after the cancel: \(stray)")
    }
}

private final class Seen: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []
    func add(_ value: Double) { lock.withLock { values.append(value) } }
    func waitUntil(_ condition: (Double) -> Bool) async throws {
        for _ in 0..<200 {
            if lock.withLock({ values.contains(where: condition) }) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw CocoaError(.fileReadUnknown)
    }
}
