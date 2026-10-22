import CoreGraphics
import Foundation
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

struct PDFTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    private func names(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    @Test func singlePagePDFBecomesOneImage() async throws {
        let pdf = try TestImages.makePDF("one.pdf", pages: 1, in: dir)
        let out = try await ConverterRegistry.standard.convert(
            ConversionJob(input: pdf, outputType: .png, outputDirectory: dir))
        #expect(out.lastPathComponent == "one.png")
        let source = try #require(CGImageSourceCreateWithURL(out as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        // 200x100 pt at 150 dpi is about 417x208 (PDFKit may round either way)
        #expect(abs(image.width - 417) <= 1)
        #expect(abs(image.height - 208) <= 1)
    }

    @Test func multiPagePDFBecomesAFolderOfImages() async throws {
        let pdf = try TestImages.makePDF("doc.pdf", pages: 3, in: dir)
        let out = try await ConverterRegistry.standard.convert(
            ConversionJob(input: pdf, outputType: .jpeg, outputDirectory: dir))
        #expect(out.lastPathComponent == "doc")
        #expect(isDirectory(out))
        #expect(try names(in: out) == ["doc-001.jpg", "doc-002.jpg", "doc-003.jpg"])
    }

    @Test func corruptPDFThrows() async throws {
        let bad = dir.appendingPathComponent("bad.pdf")
        try Data("not a pdf".utf8).write(to: bad)
        await #expect(throws: ConversionError.self) {
            try await ConverterRegistry.standard.convert(
                ConversionJob(input: bad, outputType: .png, outputDirectory: dir))
        }
    }

    @Test func cancelledPDFConversionLeavesNothingBehind() async throws {
        let pdf = try TestImages.makePDF("c.pdf", pages: 3, in: dir)
        let job = ConversionJob(input: pdf, outputType: .png, outputDirectory: dir)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ConverterRegistry.standard.convert(job)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try names(in: dir) == ["c.pdf"])
    }

    @Test func mergeCombinesPDFsAndImages() async throws {
        let a = try TestImages.makePDF("a.pdf", pages: 2, in: dir)
        let b = try TestImages.makePDF("b.pdf", pages: 1, in: dir)
        let image = try TestImages.make("p.png", type: .png, in: dir)

        let merged = try await PDFTools.merge([a, image, b], outputDirectory: dir)
        #expect(merged.lastPathComponent == "Merged.pdf")
        #expect(PDFDocument(url: merged)?.pageCount == 4)

        let again = try await PDFTools.merge([a, b], outputDirectory: dir)
        #expect(again.lastPathComponent == "Merged (1).pdf")
        #expect(FileManager.default.fileExists(atPath: merged.path))
    }

    @Test func splitWritesOnePDFPerPage() async throws {
        let pdf = try TestImages.makePDF("book.pdf", pages: 3, in: dir)
        let folder = try await PDFTools.split(pdf, outputDirectory: dir)
        #expect(folder.lastPathComponent == "book-pages")
        let files = try names(in: folder)
        #expect(files == ["book-001.pdf", "book-002.pdf", "book-003.pdf"])
        for file in files {
            #expect(PDFDocument(url: folder.appendingPathComponent(file))?.pageCount == 1)
        }
    }

    @Test func mergeFailsCleanlyOnBadInput() async throws {
        let good = try TestImages.makePDF("g.pdf", pages: 1, in: dir)
        let bad = dir.appendingPathComponent("bad.pdf")
        try Data("nope".utf8).write(to: bad)
        await #expect(throws: ConversionError.self) {
            try await PDFTools.merge([good, bad], outputDirectory: dir)
        }
        #expect(try names(in: dir) == ["bad.pdf", "g.pdf"])
    }

    @MainActor
    @Test func queueRunsMergeAndSplit() async throws {
        let a = try TestImages.makePDF("qa.pdf", pages: 2, in: dir)
        let b = try TestImages.makePDF("qb.pdf", pages: 2, in: dir)
        let model = QueueViewModel()
        model.addMerge([a, b])
        model.addSplit([a])
        await model.waitUntilIdle()

        let done = model.items.compactMap { item -> String? in
            if case .done(let url) = item.state { url.lastPathComponent } else { nil }
        }
        #expect(done == ["Merged.pdf", "qa-pages"])
    }

    @MainActor
    @Test func mergeNeedsAtLeastTwoFiles() throws {
        let a = try TestImages.makePDF("solo.pdf", pages: 1, in: dir)
        let model = QueueViewModel()
        model.addMerge([a])
        #expect(model.items.isEmpty)
    }
}
