import Foundation
import UniformTypeIdentifiers

/// MP3 output, MKV in and out, and anything else macOS can't do, through the user's ffmpeg.
/// Offers nothing when ffmpeg isn't installed.
struct FFmpegConverter: Converter {
    private static let audioOutputs: Set<UTType> = [.mp3, MediaFormats.m4a, .wav, MediaFormats.flac]
    private static let videoOutputs: Set<UTType> = [MediaFormats.mp4, MediaFormats.mov, MediaFormats.mkv]

    private let override: URL?

    /// `executable` is for tests; normally ffmpeg is found by `FFmpegLocator`.
    init(executable: URL? = nil) {
        override = executable
    }

    /// An explicit path that doesn't exist counts as "not installed", never as a fallback.
    private var executable: URL? {
        guard let override else { return FFmpegLocator.url }
        return FileManager.default.isExecutableFile(atPath: override.path) ? override : nil
    }

    var supportedInputs: Set<UTType> {
        executable == nil ? [] : MediaFormats.audioInputs.union(MediaFormats.allVideo)
    }

    var outputs: Set<UTType> {
        executable == nil ? [] : Self.audioOutputs.union(Self.videoOutputs)
    }

    /// Audio and video may become audio; only video may become video.
    func canConvert(from input: UTType, to output: UTType) -> Bool {
        guard executable != nil, input != output else { return false }
        let isVideo = MediaFormats.allVideo.contains { input.conforms(to: $0) }
        let isAudio = MediaFormats.audioInputs.contains { input.conforms(to: $0) }
        if Self.audioOutputs.contains(output) { return isVideo || isAudio }
        if Self.videoOutputs.contains(output) { return isVideo }
        return false
    }

    func convert(_ job: ConversionJob, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard let executable else { throw ConversionError.toolMissing }
        try Task.checkCancellation()
        progress(0)
        let url = try await SafeWrite.write(
            in: job.outputDirectory,
            pathExtension: OutputPath.fileExtension(for: job.outputType),
            finalURL: { OutputPath.uniqueURL(for: job.input, type: job.outputType, in: job.outputDirectory) }
        ) { temp in
            let arguments = Self.arguments(input: job.input, output: temp, type: job.outputType, quality: job.quality)
            try await FFmpegRun.run(executable, arguments: arguments, progress: progress)
        }
        progress(1)
        return url
    }

    /// The ffmpeg command line. Audio targets drop the picture (`-vn`).
    static func arguments(input: URL, output: URL, type: UTType, quality: Double) -> [String] {
        var arguments = [
            "-nostdin", "-y", "-hide_banner", "-loglevel", "info",
            "-progress", "pipe:1", "-nostats", "-i", input.path,
        ]
        switch type {
        case .mp3:
            arguments += ["-vn", "-c:a", "libmp3lame", "-q:a", String(Int(((1 - quality) * 9).rounded()))]
        case MediaFormats.m4a:
            arguments += ["-vn", "-c:a", "aac", "-b:a", "\(Int(96 + quality * 160))k"]
        case .wav:
            arguments += ["-vn", "-c:a", "pcm_s16le"]
        case MediaFormats.flac:
            arguments += ["-vn", "-c:a", "flac"]
        case MediaFormats.mkv:
            arguments += ["-c", "copy"] // re-wrap, no quality loss
        default: // MP4 / MOV: hardware H.264 and AAC
            arguments += ["-c:v", "h264_videotoolbox", "-q:v", String(Int(quality * 100)), "-c:a", "aac"]
        }
        return arguments + [output.path]
    }
}

/// Runs ffmpeg, turns its `-progress` output into 0...1, and stops it when the task is cancelled.
enum FFmpegRun {
    static func run(
        _ executable: URL,
        arguments: [String],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let box = ProcessBox()
        let process = box.process
        process.executableURL = executable
        process.arguments = arguments
        let stdout = Pipe(), stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        let parser = OutputParser(progress: progress)
        stdout.fileHandleForReading.readabilityHandler = { parser.consumeOutput($0.availableData) }
        stderr.fileHandleForReading.readabilityHandler = { parser.consumeLog($0.availableData) }
        defer {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
        }

        try Task.checkCancellation()
        do { try process.run() } catch { throw ConversionError.toolMissing }

        await withTaskCancellationHandler {
            await Task.detached { box.process.waitUntilExit() }.value
        } onCancel: {
            box.process.terminate()
        }

        parser.consumeOutput(stdout.fileHandleForReading.readDataToEndOfFile())
        parser.consumeLog(stderr.fileHandleForReading.readDataToEndOfFile())
        try Task.checkCancellation()
        guard process.terminationStatus == 0 else { throw ConversionError.toolFailed(parser.lastLogLine) }
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()
}

/// Reads ffmpeg's log (for the clip length and error text) and its `-progress` key=value lines.
final class OutputParser: @unchecked Sendable {
    private let lock = NSLock()
    private let progress: @Sendable (Double) -> Void
    private var duration: Double?
    private var log = ""
    private var pending = ""

    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progress = progress
    }

    var lastLogLine: String {
        lock.withLock {
            log.split(separator: "\n").last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "unknown error"
        }
    }

    func consumeLog(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
        lock.withLock {
            log = String((log + text).suffix(4000))
            if duration == nil { duration = Self.duration(in: log) }
        }
    }

    func consumeOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
        var fractions: [Double] = []
        lock.withLock {
            pending += text
            let lines = pending.components(separatedBy: "\n")
            pending = lines.last ?? ""
            for line in lines.dropLast() {
                // Both keys are microseconds, despite the name of the second.
                guard line.hasPrefix("out_time_us=") || line.hasPrefix("out_time_ms="),
                      let micros = Double(line.drop { $0 != "=" }.dropFirst()),
                      let duration, duration > 0 else { continue }
                fractions.append(min(max(micros / 1_000_000 / duration, 0), 0.99))
            }
        }
        fractions.forEach(progress)
    }

    /// "Duration: 00:01:23.45" → seconds.
    static func duration(in log: String) -> Double? {
        guard let match = log.firstMatch(of: /Duration: (\d+):(\d+):(\d+(?:\.\d+)?)/),
              let hours = Double(match.1), let minutes = Double(match.2), let seconds = Double(match.3)
        else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}
