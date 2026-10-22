import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

struct ImageConversionTests {
    let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tangerine-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func makeImage(_ name: String, type: UTType) throws -> URL {
        try TestImages.make(name, type: type, in: dir)
    }

    private func size(of url: URL) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (image.width, image.height)
    }

    private func job(_ input: URL, to type: UTType) -> ConversionJob {
        ConversionJob(input: input, outputType: type, outputDirectory: dir)
    }

    @Test func pngToJpeg() async throws {
        let input = try makeImage("a.png", type: .png)
        let output = try await ConverterRegistry.standard.convert(job(input, to: .jpeg))
        #expect(output.lastPathComponent == "a.jpg")
        let type = try output.resourceValues(forKeys: [.contentTypeKey]).contentType
        #expect(type == .jpeg)
        #expect(size(of: output)! == (8, 4))
    }

    @Test func jpegToPng() async throws {
        let input = try makeImage("b.jpg", type: .jpeg)
        let output = try await ConverterRegistry.standard.convert(job(input, to: .png))
        let type = try output.resourceValues(forKeys: [.contentTypeKey]).contentType
        #expect(type == .png)
        #expect(size(of: output)! == (8, 4))
    }

    @Test func existingFileIsNeverOverwritten() async throws {
        let input = try makeImage("c.png", type: .png)
        let first = try await ConverterRegistry.standard.convert(job(input, to: .jpeg))
        let second = try await ConverterRegistry.standard.convert(job(input, to: .jpeg))
        #expect(first.lastPathComponent == "c.jpg")
        #expect(second.lastPathComponent == "c (1).jpg")
        #expect(FileManager.default.fileExists(atPath: first.path))
    }

    @Test func unsupportedConversionThrows() async throws {
        let input = try makeImage("d.png", type: .png)
        await #expect(throws: ConversionError.self) {
            try await ConverterRegistry.standard.convert(job(input, to: .mp3))
        }
    }

    @Test func corruptInputThrows() async throws {
        let input = dir.appendingPathComponent("bad.png")
        try Data("not an image".utf8).write(to: input)
        await #expect(throws: ConversionError.self) {
            try await ConverterRegistry.standard.convert(job(input, to: .jpeg))
        }
    }

    @Test func cancelledJobLeavesNoOutput() async throws {
        let input = try makeImage("e.png", type: .png)
        let job = job(input, to: .jpeg)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ConverterRegistry.standard.convert(job)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files == ["e.png"])
    }

    @Test func outputsExcludeTheInputType() {
        let outputs = ConverterRegistry.standard.outputs(for: .png)
        #expect(outputs == ImageFormats.writable.subtracting([.png]).union([.pdf]))
    }
}

struct WriteFailureTests {
    @Test func unwritableOutputFolderFailsCleanlyWithAReadableMessage() async throws {
        let dir = try TestImages.makeTempDir()
        let input = try TestImages.make("a.png", type: .png, in: dir)
        let locked = dir.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let error = await #expect(throws: ConversionError.self) {
            try await ConverterRegistry.standard.convert(
                ConversionJob(input: input, outputType: .jpeg, outputDirectory: locked))
        }
        #expect(error?.errorDescription?.isEmpty == false)
        #expect(try FileManager.default.contentsOfDirectory(atPath: locked.path).isEmpty)
    }

    @Test func everyErrorHasAMessage() {
        let url = URL(fileURLWithPath: "/tmp/x.pdf")
        let errors: [ConversionError] = [
            .unreadableInput(url), .unsupportedConversion(from: .png, to: .mp3),
            .writeFailed(url), .passwordProtected(url), .emptyDocument(url), .noText(url),
        ]
        for error in errors {
            #expect(error.errorDescription?.contains("x.pdf") == true || error.errorDescription?.isEmpty == false)
        }
    }
}
