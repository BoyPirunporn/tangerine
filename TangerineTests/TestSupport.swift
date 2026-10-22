import AppKit
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
