import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

/// ffmpeg itself isn't needed: these use small shell scripts that behave like it.
struct FFmpegTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    private func script(_ name: String, _ body: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try ("#!/bin/zsh\n" + body).write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    /// Announces a 2 s clip, reports progress, writes the output (last argument) and exits 0.
    private func fakeFFmpeg() throws -> URL {
        try script("ffmpeg-ok", """
        out="${@: -1}"
        echo "  Duration: 00:00:02.00, start: 0.000000" >&2
        printf 'out_time_us=500000\\nprogress=continue\\nout_time_us=1000000\\nprogress=continue\\n'
        print -r -- "$@" > "$out"
        printf 'out_time_us=2000000\\nprogress=end\\n'
        """)
    }

    private func job(_ input: URL, _ type: UTType) -> ConversionJob {
        ConversionJob(input: input, outputType: type, outputDirectory: dir)
    }

    private func collect() -> (Collector, @Sendable (Double) -> Void) {
        let collector = Collector()
        return (collector, { collector.add($0) })
    }

    // MARK: availability

    @Test func offersNothingWithoutFFmpeg() {
        let missing = FFmpegConverter(executable: URL(fileURLWithPath: "/nonexistent/ffmpeg"))
        #expect(missing.outputs.isEmpty)
        #expect(missing.supportedInputs.isEmpty)
        #expect(!missing.canConvert(from: MediaFormats.mp4, to: .mp3))
    }

    @Test func offersMp3AndMkvWithFFmpeg() throws {
        let converter = FFmpegConverter(executable: try fakeFFmpeg())
        #expect(converter.outputs.contains(.mp3))
        #expect(converter.outputs.contains(MediaFormats.mkv))
        #expect(converter.canConvert(from: MediaFormats.mp4, to: .mp3))
        #expect(converter.canConvert(from: .wav, to: .mp3))
        #expect(converter.canConvert(from: MediaFormats.mkv, to: MediaFormats.mp4))
        #expect(converter.canConvert(from: MediaFormats.mp4, to: MediaFormats.mkv))
    }

    @Test func audioCannotBecomeVideo() throws {
        let converter = FFmpegConverter(executable: try fakeFFmpeg())
        #expect(!converter.canConvert(from: .wav, to: MediaFormats.mp4))
        #expect(!converter.canConvert(from: .mp3, to: MediaFormats.mkv))
        #expect(!converter.canConvert(from: .png, to: .mp3))
        #expect(!converter.canConvert(from: .mp3, to: .mp3))
    }

    @Test func registryPrefersNativeConvertersAndAddsFFmpegForTheRest() throws {
        let registry = ConverterRegistry(converters: ConverterRegistry.native.converters
            + [FFmpegConverter(executable: try fakeFFmpeg())])
        #expect(registry.converter(from: MediaFormats.mp4, to: MediaFormats.mov) is VideoExportConverter)
        #expect(registry.converter(from: .wav, to: MediaFormats.flac) is AudioFileConverter)
        #expect(registry.converter(from: MediaFormats.mp4, to: .mp3) is FFmpegConverter)
        #expect(registry.converter(from: MediaFormats.mkv, to: .wav) is FFmpegConverter)
        #expect(registry.outputs(for: MediaFormats.mkv) ==
                [MediaFormats.mp4, MediaFormats.mov, MediaFormats.m4a, .mp3, .wav, MediaFormats.flac])
    }

    @Test func mkvFilesAreRecognisedBySystem() throws {
        let file = dir.appendingPathComponent("movie.mkv")
        try Data("x".utf8).write(to: file)
        #expect(try file.resourceValues(forKeys: [.contentTypeKey]).contentType == MediaFormats.mkv)
        #expect(OutputPath.fileExtension(for: MediaFormats.mkv) == "mkv")
    }

    // MARK: command line

    @Test func commandLinesMatchTheTarget() {
        let input = URL(fileURLWithPath: "/in/a.mp4"), output = URL(fileURLWithPath: "/out/a.x")
        func args(_ type: UTType, _ quality: Double = 0.85) -> [String] {
            FFmpegConverter.arguments(input: input, output: output, type: type, quality: quality)
        }
        #expect(args(.mp3).contains("libmp3lame"))
        #expect(args(.mp3).contains("-vn"))
        #expect(args(.mp3, 1)[args(.mp3, 1).firstIndex(of: "-q:a")! + 1] == "0")   // best
        #expect(args(.mp3, 0)[args(.mp3, 0).firstIndex(of: "-q:a")! + 1] == "9")   // smallest
        #expect(args(MediaFormats.mkv).contains("copy"))
        #expect(args(MediaFormats.mp4).contains("h264_videotoolbox"))
        #expect(args(.wav).contains("pcm_s16le"))
        #expect(args(MediaFormats.flac).contains("flac"))
        for type in [UTType.mp3, MediaFormats.mkv, MediaFormats.mp4, .wav] {
            let list = args(type)
            #expect(list[list.firstIndex(of: "-i")! + 1] == "/in/a.mp4")
            #expect(list.last == "/out/a.x")
            #expect(list.contains("-progress"))
            #expect(list.contains("-nostdin"))
        }
    }

    // MARK: running it

    @Test func runsFFmpegWritesTheFileAndReportsProgress() async throws {
        let converter = FFmpegConverter(executable: try fakeFFmpeg())
        let input = dir.appendingPathComponent("song.wav")
        try Data("x".utf8).write(to: input)
        let (collector, report) = collect()

        let output = try await converter.convert(job(input, .mp3), progress: report)
        #expect(output.lastPathComponent == "song.mp3")
        #expect(try String(contentsOf: output, encoding: .utf8).contains("libmp3lame"))

        let values = collector.values
        #expect(values.first == 0 && values.last == 1)
        #expect(values.contains { abs($0 - 0.25) < 0.01 })   // 0.5 s of a 2 s clip
        #expect(values.contains { abs($0 - 0.5) < 0.01 })
        #expect(values == values.sorted())
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix(".tangerine") }.isEmpty)
    }

    @Test func ffmpegFailureCarriesItsMessageAndLeavesNothing() async throws {
        let failing = try script("ffmpeg-fail", """
        echo "Unknown encoder 'libmp3lame'" >&2
        exit 1
        """)
        let input = dir.appendingPathComponent("a.wav")
        try Data("x".utf8).write(to: input)
        let error = await #expect(throws: ConversionError.self) {
            try await FFmpegConverter(executable: failing).convert(job(input, .mp3), progress: { _ in })
        }
        guard case .toolFailed(let detail)? = error else { Issue.record("got \(String(describing: error))"); return }
        #expect(detail.contains("libmp3lame"))
        #expect(error?.errorDescription?.contains("libmp3lame") == true)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("a.mp3").path))
    }

    @Test func cancelStopsTheProcessAndRemovesPartialOutput() async throws {
        let pidFile = dir.appendingPathComponent("pid")
        let slow = try script("ffmpeg-slow", """
        out="${@: -1}"
        echo $$ > "\(pidFile.path)"
        echo "  Duration: 00:00:10.00" >&2
        print -r -- partial > "$out"
        trap 'exit 143' TERM
        for i in {1..200}; do echo out_time_us=$((i*10000)); sleep 0.1; done
        """)
        let input = dir.appendingPathComponent("long.wav")
        try Data("x".utf8).write(to: input)
        let started = Started()
        let task = Task {
            try await FFmpegConverter(executable: slow).convert(job(input, .mp3)) { value in
                if value > 0 { started.signal() }
            }
        }
        try await started.wait()
        let beforeCancel = Date()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(Date().timeIntervalSince(beforeCancel) < 3, "cancel should stop ffmpeg promptly")

        // the process is gone and nothing half-written is left
        let pid = try #require(Int32(String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        try await Task.sleep(for: .milliseconds(300))
        #expect(kill(pid, 0) != 0, "ffmpeg process \(pid) is still running")
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".mp3") || $0.hasPrefix(".tangerine") }
        #expect(left.isEmpty)
    }

    @Test func missingExecutableIsReportedClearly() async throws {
        let gone = FFmpegConverter(executable: URL(fileURLWithPath: "/nonexistent/ffmpeg"))
        let input = dir.appendingPathComponent("a.wav")
        try Data("x".utf8).write(to: input)
        let error = await #expect(throws: ConversionError.self) {
            try await gone.convert(job(input, .mp3), progress: { _ in })
        }
        guard case .toolMissing? = error else { Issue.record("got \(String(describing: error))"); return }
    }

    @Test func logParserReadsClipLength() {
        #expect(OutputParser.duration(in: "  Duration: 00:01:23.50, start: 0.0") == 83.5)
        #expect(OutputParser.duration(in: "  Duration: 01:00:00.00") == 3600)
        #expect(OutputParser.duration(in: "no duration here") == nil)
    }
}

private final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Double] = []
    func add(_ value: Double) { lock.withLock { storage.append(value) } }
    var values: [Double] { lock.withLock { storage } }
}

private final class Started: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func signal() { lock.withLock { fired = true } }
    func wait() async throws {
        for _ in 0..<100 {
            if lock.withLock({ fired }) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw CocoaError(.fileReadUnknown)
    }
}
