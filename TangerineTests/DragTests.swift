import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

struct DragTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    @Test func shiftModeNeedsShift() {
        #expect(TriggerMode.shift.shouldShow(modifiers: [.shift]))
        #expect(TriggerMode.shift.shouldShow(modifiers: [.shift, .command]))
        #expect(!TriggerMode.shift.shouldShow(modifiers: []))
        #expect(!TriggerMode.shift.shouldShow(modifiers: [.command]))
    }

    @Test func alwaysModeIgnoresModifiers() {
        #expect(TriggerMode.always.shouldShow(modifiers: []))
        #expect(TriggerMode.always.shouldShow(modifiers: [.shift]))
    }

    @Test func formatsDependOnFileType() throws {
        let registry = ConverterRegistry.standard
        let png = try TestImages.make("a.png", type: .png, in: dir)
        let pdf = try TestImages.makePDF("a.pdf", pages: 1, in: dir)

        #expect(registry.outputs(forFiles: [png]).contains(.pdf))
        #expect(!registry.outputs(forFiles: [png]).contains(.png))
        #expect(registry.outputs(forFiles: [pdf]) == [.png, .jpeg, WordFormats.docx])
    }

    @Test func mixedFilesOnlyOfferSharedFormats() throws {
        let registry = ConverterRegistry.standard
        let png = try TestImages.make("a.png", type: .png, in: dir)
        let pdf = try TestImages.makePDF("a.pdf", pages: 1, in: dir)
        // PNG can't become PNG, PDF can't become PDF: only JPEG works for both.
        #expect(registry.outputs(forFiles: [png, pdf]) == [.jpeg])
    }

    @Test func unreadableOrEmptyInputOffersNothing() {
        let registry = ConverterRegistry.standard
        #expect(registry.outputs(forFiles: []).isEmpty)
        #expect(registry.outputs(forFiles: [dir.appendingPathComponent("missing.png")]).isEmpty)
    }
}
