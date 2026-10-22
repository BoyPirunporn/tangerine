import AVFAudio
import Foundation
import UniformTypeIdentifiers

/// Audio ↔ audio with Core Audio (WAV, FLAC, M4A/AAC), also pulling the sound out of a video.
/// MP3 can be read but macOS has no MP3 encoder.
struct AudioFileConverter: Converter {
    let supportedInputs = MediaFormats.audioInputs.union(MediaFormats.videoInputs)
    let outputs: Set<UTType> = [.wav, MediaFormats.flac, MediaFormats.m4a]

    private static let chunkFrames: AVAudioFrameCount = 32_768

    func convert(_ job: ConversionJob, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        progress(0)
        let url = try SafeWrite.write(
            in: job.outputDirectory,
            pathExtension: OutputPath.fileExtension(for: job.outputType),
            finalURL: { OutputPath.uniqueURL(for: job.input, type: job.outputType, in: job.outputDirectory) }
        ) { temp in
            try Self.transcode(job, to: temp, progress: progress)
        }
        progress(1)
        return url
    }

    private static func transcode(_ job: ConversionJob, to url: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let input: AVAudioFile
        do { input = try AVAudioFile(forReading: job.input) } catch { throw ConversionError.unreadableInput(job.input) }
        guard input.length > 0 else { throw ConversionError.unreadableInput(job.input) }

        let format = input.processingFormat
        let output: AVAudioFile
        do {
            output = try AVAudioFile(
                forWriting: url,
                settings: settings(for: job.outputType, sampleRate: input.fileFormat.sampleRate,
                                   channels: format.channelCount, quality: job.quality),
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
        } catch {
            throw ConversionError.writeFailed(url)
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw ConversionError.writeFailed(url)
        }
        while input.framePosition < input.length {
            try Task.checkCancellation()
            try input.read(into: buffer)
            if buffer.frameLength == 0 { break }
            try output.write(from: buffer)
            progress(Double(input.framePosition) / Double(input.length))
        }
    }

    private static func settings(for type: UTType, sampleRate: Double, channels: AVAudioChannelCount, quality: Double) -> [String: Any] {
        var settings: [String: Any] = [AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: Int(channels)]
        switch type {
        case .wav:
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = false
            settings[AVLinearPCMIsNonInterleaved] = false
        case MediaFormats.flac:
            settings[AVFormatIDKey] = kAudioFormatFLAC
            settings[AVLinearPCMBitDepthKey] = 16
        default: // M4A / AAC: 48-128 kbps per channel
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            settings[AVEncoderBitRatePerChannelKey] = Int(48_000 + quality * 80_000)
        }
        return settings
    }
}
