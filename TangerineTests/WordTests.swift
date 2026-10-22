import AppKit
import Foundation
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

@MainActor
struct WordTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    private func convert(_ input: URL, to type: UTType) async throws -> URL {
        try await ConverterRegistry.standard.convert(
            ConversionJob(input: input, outputType: type, outputDirectory: dir)
        )
    }

    private func text(ofPDF url: URL) -> String {
        PDFDocument(url: url)?.string ?? ""
    }

    @Test func docxFixtureIsReadable() throws {
        let docx = try TestDocs.makeDocx("a.docx", text: "Hello Tangerine", in: dir)
        let read = try WordFormats.read(docx, as: WordFormats.docx)
        #expect(read.string.contains("Hello Tangerine"))
    }

    @Test func docxToPDF() async throws {
        let docx = try TestDocs.makeDocx("letter.docx", text: "Dear reader,\nThis is a test letter.", in: dir)
        let pdf = try await convert(docx, to: .pdf)
        #expect(pdf.lastPathComponent == "letter.pdf")
        let document = try #require(PDFDocument(url: pdf))
        #expect(document.pageCount == 1)
        #expect(text(ofPDF: pdf).contains("This is a test letter."))
    }

    @Test func longDocxBecomesSeveralPages() async throws {
        let paragraph = String(repeating: "Tangerines are small citrus fruits. ", count: 20)
        let docx = try TestDocs.makeDocx("long.docx", text: Array(repeating: paragraph, count: 40).joined(separator: "\n"), in: dir)
        let pdf = try await convert(docx, to: .pdf)
        #expect((PDFDocument(url: pdf)?.pageCount ?? 0) >= 2)
    }

    @Test func thaiTextConvertsWithoutError() async throws {
        let docx = try TestDocs.makeDocx("thai.docx", text: "สวัสดีครับ ทดสอบภาษาไทย", in: dir)
        let pdf = try await convert(docx, to: .pdf)
        #expect(PDFDocument(url: pdf)?.pageCount == 1)
        let txt = try await convert(docx, to: .plainText)
        #expect(try String(contentsOf: txt, encoding: .utf8).contains("สวัสดีครับ ทดสอบภาษาไทย"))
    }

    @Test func pdfToDocxKeepsTheText() async throws {
        let docx = try TestDocs.makeDocx("src.docx", text: "Quarterly report: revenue grew.", in: dir)
        let pdf = try await convert(docx, to: .pdf)
        let back = try await convert(pdf, to: WordFormats.docx)
        #expect(back.lastPathComponent == "src.docx" || back.lastPathComponent == "src (1).docx")
        let read = try WordFormats.read(back, as: WordFormats.docx)
        #expect(read.string.contains("Quarterly report: revenue grew."))
    }

    @Test func pdfWithoutTextIsRejected() async throws {
        let shapesOnly = try TestImages.makePDF("scan.pdf", pages: 1, in: dir)
        await #expect(throws: ConversionError.self) {
            try await convert(shapesOnly, to: WordFormats.docx)
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(leftovers == ["scan.pdf"])
    }

    @Test func docxToTextAndHTML() async throws {
        let docx = try TestDocs.makeDocx("note.docx", text: "Plain words here", in: dir)
        let txt = try await convert(docx, to: .plainText)
        #expect(try String(contentsOf: txt, encoding: .utf8).contains("Plain words here"))
        let html = try await convert(docx, to: .html)
        #expect(try String(contentsOf: html, encoding: .utf8).contains("Plain words here"))
    }

    @Test func textAndHTMLBecomeDocx() async throws {
        let txt = dir.appendingPathComponent("memo.txt")
        try "Memo body".write(to: txt, atomically: true, encoding: .utf8)
        let fromText = try await convert(txt, to: WordFormats.docx)
        #expect(try WordFormats.read(fromText, as: WordFormats.docx).string.contains("Memo body"))

        let htmlFile = dir.appendingPathComponent("page.html")
        try "<html><body><p>Page <b>body</b></p></body></html>".write(to: htmlFile, atomically: true, encoding: .utf8)
        let fromHTML = try await convert(htmlFile, to: WordFormats.docx)
        #expect(try WordFormats.read(fromHTML, as: WordFormats.docx).string.contains("Page body"))
    }

    @Test func corruptDocxThrowsAndLeavesNothing() async throws {
        let bad = dir.appendingPathComponent("bad.docx")
        try Data("this is not a zip".utf8).write(to: bad)
        await #expect(throws: ConversionError.self) { try await convert(bad, to: .pdf) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["bad.docx"])
    }

    @Test func sourceCodeIsNotOfferedAsWord() {
        let registry = ConverterRegistry.standard
        #expect(registry.converter(from: .swiftSource, to: WordFormats.docx) == nil)
        #expect(registry.converter(from: .plainText, to: WordFormats.docx) != nil)
    }

    @Test func formatsOfferedForWordFiles() throws {
        let docx = try TestDocs.makeDocx("o.docx", text: "x", in: dir)
        #expect(ConverterRegistry.standard.outputs(forFiles: [docx]) == [.pdf, .plainText, .html])
        let pdf = try TestImages.makePDF("o.pdf", pages: 1, in: dir)
        #expect(ConverterRegistry.standard.outputs(forFiles: [pdf]) == [.png, .jpeg, WordFormats.docx])
    }

    @Test func limitsAreSurfaced() {
        #expect(ConversionLimits.note(from: .pdf, to: WordFormats.docx) != nil)
        #expect(ConversionLimits.note(from: WordFormats.docx, to: .pdf) != nil)
        #expect(ConversionLimits.note(from: .gif, to: .png) != nil)
        #expect(ConversionLimits.note(from: .png, to: .jpeg) == nil)
        #expect(ConversionLimits.note(from: nil, to: .jpeg) == nil)
    }

    @Test func queueShowsTheLimitNote() async throws {
        let docx = try TestDocs.makeDocx("q.docx", text: "queue", in: dir)
        let pdf = try await convert(docx, to: .pdf)
        let model = QueueViewModel()
        model.add([pdf], as: WordFormats.docx)
        #expect(model.items.first?.note == ConversionLimits.note(from: .pdf, to: WordFormats.docx))
        await model.waitUntilIdle()
    }
}
