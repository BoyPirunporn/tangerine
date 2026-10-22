import AVFoundation
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

struct MediaTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    private func convert(_ input: URL, to type: UTType) async throws -> URL {
        try await ConverterRegistry.standard.convert(
            ConversionJob(input: input, outputType: type, outputDirectory: dir))
    }

    private func contentType(_ url: URL) throws -> UTType? {
        try url.resourceValues(forKeys: [.contentTypeKey]).contentType
    }

    private func hasTrack(_ url: URL, _ type: AVMediaType) async throws -> Bool {
        try await !AVURLAsset(url: url).loadTracks(withMediaType: type).isEmpty
    }

    // MARK: audio

    @Test func wavToFlacAndBack() async throws {
        let wav = try TestMedia.makeWAV("tone.wav", in: dir)
        let flac = try await convert(wav, to: MediaFormats.flac)
        #expect(flac.lastPathComponent == "tone.flac")
        #expect(try contentType(flac) == MediaFormats.flac)
        #expect(abs(try TestMedia.duration(of: flac) - 1) < 0.05)

        let back = try await convert(flac, to: .wav)
        #expect(abs(try TestMedia.duration(of: back) - 1) < 0.05)
    }

    @Test func wavToM4AAndBack() async throws {
        let wav = try TestMedia.makeWAV("voice.wav", in: dir)
        let m4a = try await convert(wav, to: MediaFormats.m4a)
        #expect(m4a.lastPathComponent == "voice.m4a")
        #expect(abs(try TestMedia.duration(of: m4a) - 1) < 0.15) // AAC adds a little padding

        let back = try await convert(m4a, to: .wav)
        #expect(abs(try TestMedia.duration(of: back) - 1) < 0.15)
    }

    @Test func existingAudioIsNotOverwritten() async throws {
        let wav = try TestMedia.makeWAV("same.wav", in: dir)
        _ = try await convert(wav, to: MediaFormats.flac)
        let second = try await convert(wav, to: MediaFormats.flac)
        #expect(second.lastPathComponent == "same (1).flac")
    }

    @Test func mp3AndMkvNeedFFmpeg() {
        #expect(!ConverterRegistry.native.allOutputs.contains(.mp3))
        #expect(!ConverterRegistry.native.allOutputs.contains(MediaFormats.mkv))
    }

    // MARK: video

    @Test func mp4ToMovAndBack() async throws {
        let mp4 = try await TestMedia.makeVideo("clip.mp4", withAudio: true, in: dir)
        let mov = try await convert(mp4, to: MediaFormats.mov)
        #expect(mov.lastPathComponent == "clip.mov")
        #expect(try contentType(mov) == MediaFormats.mov)
        #expect(try await hasTrack(mov, .video))
        #expect(try await hasTrack(mov, .audio))

        let back = try await convert(mov, to: MediaFormats.mp4)
        #expect(try contentType(back) == MediaFormats.mp4)
        #expect(try await hasTrack(back, .video))
    }

    @Test func videoToM4A() async throws {
        let mp4 = try await TestMedia.makeVideo("talk.mp4", withAudio: true, in: dir)
        let m4a = try await convert(mp4, to: MediaFormats.m4a)
        #expect(try contentType(m4a) == MediaFormats.m4a)
        #expect(abs(try TestMedia.duration(of: m4a) - 1) < 0.2)
        #expect(try await !hasTrack(m4a, .video))
    }

    @Test func videoToWavAndFlac() async throws {
        let mp4 = try await TestMedia.makeVideo("sound.mp4", withAudio: true, in: dir)
        let wav = try await convert(mp4, to: .wav)
        #expect(abs(try TestMedia.duration(of: wav) - 1) < 0.2)
        let flac = try await convert(mp4, to: MediaFormats.flac)
        #expect(abs(try TestMedia.duration(of: flac) - 1) < 0.2)
    }

    @Test func videoWithoutSoundCannotBecomeAudio() async throws {
        let silent = try await TestMedia.makeVideo("mute.mp4", withAudio: false, in: dir)
        let error = await #expect(throws: ConversionError.self) { try await convert(silent, to: MediaFormats.m4a) }
        guard case .noAudioTrack? = error else { Issue.record("expected noAudioTrack, got \(String(describing: error))"); return }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["mute.mp4"])
    }

    // MARK: failures and cancel

    @Test func corruptMediaFailsCleanly() async throws {
        let bad = dir.appendingPathComponent("bad.wav")
        try Data("not audio".utf8).write(to: bad)
        await #expect(throws: ConversionError.self) { try await convert(bad, to: MediaFormats.flac) }
        let badVideo = dir.appendingPathComponent("bad.mp4")
        try Data("not video".utf8).write(to: badVideo)
        await #expect(throws: ConversionError.self) { try await convert(badVideo, to: MediaFormats.mov) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted() == ["bad.mp4", "bad.wav"])
    }

    @Test func cancelledMediaJobsLeaveNothingBehind() async throws {
        let wav = try TestMedia.makeWAV("c.wav", in: dir)
        let mp4 = try await TestMedia.makeVideo("c.mp4", withAudio: true, in: dir)
        let before = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        for (input, type) in [(wav, MediaFormats.flac), (mp4, MediaFormats.mov), (mp4, MediaFormats.m4a)] {
            let job = ConversionJob(input: input, outputType: type, outputDirectory: dir)
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await ConverterRegistry.standard.convert(job)
            }
            await #expect(throws: CancellationError.self) { try await task.value }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted() == before)
    }

    // MARK: what the menu offers

    @Test func formatsOfferedForMediaFiles() async throws {
        let registry = ConverterRegistry.native
        let wav = try TestMedia.makeWAV("o.wav", in: dir)
        #expect(registry.outputs(forFiles: [wav]) == [MediaFormats.m4a, MediaFormats.flac])
        let mp4 = try await TestMedia.makeVideo("o.mp4", withAudio: true, in: dir)
        #expect(registry.outputs(forFiles: [mp4]) == [MediaFormats.mov, MediaFormats.m4a, .wav, MediaFormats.flac])
    }

    @MainActor
    @Test func displayOrderPutsMediaAfterDocuments() {
        let ordered = QueueViewModel.ordered([MediaFormats.flac, .wav, .pdf, MediaFormats.mp4])
        #expect(ordered == [.pdf, MediaFormats.mp4, .wav, MediaFormats.flac])
    }
}
