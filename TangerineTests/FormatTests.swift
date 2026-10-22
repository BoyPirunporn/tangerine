import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

struct FormatTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    private func convert(_ input: URL, to type: UTType) async throws -> URL {
        try await ConverterRegistry.standard.convert(
            ConversionJob(input: input, outputType: type, outputDirectory: dir)
        )
    }

    private func contentType(_ url: URL) throws -> UTType? {
        try url.resourceValues(forKeys: [.contentTypeKey]).contentType
    }

    @Test(arguments: [UTType.tiff, .gif, .bmp, .heic, ImageFormats.avif])
    func roundTripsThroughPNG(_ type: UTType) async throws {
        try #require(ImageFormats.writable.contains(type), "\(type) can't be written on this Mac")
        let ext = OutputPath.fileExtension(for: type)
        let original = try TestImages.make("src.\(ext)", type: type, in: dir)

        let png = try await convert(original, to: .png)
        #expect(try contentType(png) == .png)

        let back = try await convert(png, to: type)
        #expect(try contentType(back) == type)
    }

    @Test(arguments: [UTType.tiff, .gif, .bmp])
    func convertsToJpeg(_ type: UTType) async throws {
        let original = try TestImages.make("img.\(OutputPath.fileExtension(for: type))", type: type, in: dir)
        let jpeg = try await convert(original, to: .jpeg)
        #expect(try contentType(jpeg) == .jpeg)
    }

    @Test func readsWebP() async throws {
        // 1x1 lossless WebP.
        let data = try #require(Data(base64Encoded: "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA=="))
        let input = dir.appendingPathComponent("tiny.webp")
        try data.write(to: input)

        let png = try await convert(input, to: .png)
        #expect(try contentType(png) == .png)
    }

    @Test func webPIsNotOfferedAsOutput() {
        #expect(!ConverterRegistry.standard.allOutputs.contains(.webP))
    }

    @Test func imageToPDFMakesOnePage() async throws {
        let input = try TestImages.make("pic.png", type: .png, in: dir)
        let pdf = try await convert(input, to: .pdf)
        #expect(pdf.lastPathComponent == "pic.pdf")
        #expect(CGPDFDocument(pdf as CFURL)?.numberOfPages == 1)
    }

    @Test func outputsForPDF() {
        #expect(ConverterRegistry.standard.outputs(for: .pdf) == [.png, .jpeg, WordFormats.docx])
    }
}
