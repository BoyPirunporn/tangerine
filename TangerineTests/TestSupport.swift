import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

enum TestImages {
    /// Writes a small image with a transparent corner so alpha handling is exercised.
    static func make(_ name: String, type: UTType, in dir: URL) throws -> URL {
        let context = CGContext(
            data: nil, width: 8, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let url = dir.appendingPathComponent(name)
        let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    /// A PDF with `pages` letter-sized pages.
    static func makePDF(_ name: String, pages: Int, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        var box = CGRect(x: 0, y: 0, width: 200, height: 100)
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: 10, y: 10, width: 80, height: 40))
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tangerine-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

@MainActor
enum TestDocs {
    /// Writes a real DOCX by exporting an attributed string through AppKit.
    static func makeDocx(_ name: String, text: String, in dir: URL) throws -> URL {
        let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        let url = dir.appendingPathComponent(name)
        try WordFormats.write(attributed, as: WordFormats.docx, to: url)
        return url
    }
}

enum TestMedia {
    /// A mono 440 Hz tone.
    static func makeWAV(_ name: String, seconds: Double = 1, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let frames = AVAudioFrameCount(44_100 * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for index in 0..<Int(frames) { samples[index] = 0.3 * sin(2 * .pi * 440 * Float(index) / 44_100) }
        try file.write(from: buffer)
        return url
    }

    static func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }

    /// A 160x120 H.264 clip of changing colour, `seconds` long, optionally with the tone as sound.
    static func makeVideo(_ name: String, seconds: Int = 1, withAudio: Bool, in dir: URL) async throws -> URL {
        let silent = dir.appendingPathComponent(withAudio ? "silent-\(UUID().uuidString).mp4" : name)
        let writer = try AVAssetWriter(outputURL: silent, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 120,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 120,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<(15 * seconds) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, 160, 120, kCVPixelFormatType_32BGRA, nil, &buffer)
            let pixels = buffer!
            CVPixelBufferLockBaseAddress(pixels, [])
            memset(CVPixelBufferGetBaseAddress(pixels), Int32((frame * 17) % 255), CVPixelBufferGetDataSize(pixels))
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 15))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw CocoaError(.fileWriteUnknown) }
        guard withAudio else { return silent }

        // Mux the tone into the clip.
        let wav = try makeWAV("tone-\(UUID().uuidString).wav", seconds: Double(seconds), in: dir)
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: silent), audioAsset = AVURLAsset(url: wav)
        let videoTrack = try await videoAsset.loadTracks(withMediaType: .video)[0]
        let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio)[0]
        let range = CMTimeRange(start: .zero, duration: try await videoAsset.load(.duration))
        try composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)?
            .insertTimeRange(range, of: videoTrack, at: .zero)
        try composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)?
            .insertTimeRange(range, of: audioTrack, at: .zero)
        let output = dir.appendingPathComponent(name)
        let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
        session.outputURL = output
        session.outputFileType = .mp4
        await withCheckedContinuation { continuation in session.exportAsynchronously { continuation.resume() } }
        guard session.status == .completed else { throw CocoaError(.fileWriteUnknown) }
        return output
    }
}
