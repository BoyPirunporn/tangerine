import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// MP4 ↔ MOV (re-wrapped without re-encoding when the codecs allow, otherwise re-encoded)
/// and MP4/MOV → M4A.
struct VideoExportConverter: Converter {
    let supportedInputs = MediaFormats.videoInputs
    let outputs: Set<UTType> = [MediaFormats.mp4, MediaFormats.mov, MediaFormats.m4a]

    func convert(_ job: ConversionJob, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try Task.checkCancellation()
        progress(0)
        let asset = AVURLAsset(url: job.input)
        guard (try? await asset.load(.isReadable)) == true else { throw ConversionError.unreadableInput(job.input) }

        let toAudio = job.outputType == MediaFormats.m4a
        if toAudio {
            let audio = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
            guard !audio.isEmpty else { throw ConversionError.noAudioTrack(job.input) }
        }
        let fileType: AVFileType = toAudio ? .m4a : (job.outputType == MediaFormats.mov ? .mov : .mp4)
        let preset = await Self.preset(for: asset, fileType: fileType, audioOnly: toAudio)

        let url = try await SafeWrite.write(
            in: job.outputDirectory,
            pathExtension: OutputPath.fileExtension(for: job.outputType),
            finalURL: { OutputPath.uniqueURL(for: job.input, type: job.outputType, in: job.outputDirectory) }
        ) { temp in
            try await Self.export(asset, preset: preset, fileType: fileType, to: temp, input: job.input, progress: progress)
        }
        progress(1)
        return url
    }

    private static func preset(for asset: AVAsset, fileType: AVFileType, audioOnly: Bool) async -> String {
        if audioOnly { return AVAssetExportPresetAppleM4A }
        let compatible = await AVAssetExportSession.compatibility(
            ofExportPreset: AVAssetExportPresetPassthrough, with: asset, outputFileType: fileType)
        return compatible ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
    }

    private static func export(
        _ asset: AVAsset, preset: String, fileType: AVFileType, to url: URL, input: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw ConversionError.unreadableInput(input)
        }
        session.outputURL = url
        session.outputFileType = fileType
        let box = SessionBox(session: session)

        // Report progress while the export runs.
        let reporter = Task {
            while !Task.isCancelled {
                progress(Double(box.session.progress))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { reporter.cancel() }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                box.session.exportAsynchronously { continuation.resume() }
            }
        } onCancel: {
            box.session.cancelExport()
        }
        try Task.checkCancellation()
        guard session.status == .completed else { throw ConversionError.writeFailed(url) }
    }
}

/// AVAssetExportSession is documented as safe to poll and cancel from other threads.
private struct SessionBox: @unchecked Sendable {
    let session: AVAssetExportSession
}
