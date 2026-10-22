import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

@MainActor
struct QueueViewModelTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    @Test func convertsDroppedFileNextToOriginal() async throws {
        let input = try TestImages.make("a.png", type: .png, in: dir)
        let model = QueueViewModel()
        model.targetType = .jpeg
        model.add([input])
        await model.waitUntilIdle()

        let expected = dir.appendingPathComponent("a.jpg")
        #expect(model.items.map(\.state) == [.done(expected)])
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    @Test func usesChosenOutputFolder() async throws {
        let input = try TestImages.make("b.png", type: .png, in: dir)
        let out = dir.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let model = QueueViewModel()
        model.outputDirectory = out
        model.add([input])
        await model.waitUntilIdle()

        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("b.jpg").path))
    }

    @Test func settingsAreCapturedWhenFileIsAdded() async throws {
        let png = try TestImages.make("c.png", type: .png, in: dir)
        let jpg = try TestImages.make("c.jpg", type: .jpeg, in: dir)
        let model = QueueViewModel()
        model.targetType = .jpeg
        model.add([png])
        model.targetType = .png
        model.add([jpg])
        let types = model.items.compactMap { item -> UTType? in
            if case .convert(let job) = item.work { job.outputType } else { nil }
        }
        #expect(types == [.jpeg, .png])
        await model.waitUntilIdle()
    }

    @Test func failureIsReportedPerItemAndQueueContinues() async throws {
        let bad = dir.appendingPathComponent("bad.png")
        try Data("nope".utf8).write(to: bad)
        let good = try TestImages.make("good.png", type: .png, in: dir)
        let model = QueueViewModel()
        model.add([bad, good])
        await model.waitUntilIdle()

        guard case .failed = model.items[0].state else {
            Issue.record("expected failure, got \(model.items[0].state)")
            return
        }
        guard case .done = model.items[1].state else {
            Issue.record("expected done, got \(model.items[1].state)")
            return
        }
    }

    @Test func foldersAreExpandedToConvertibleFilesOnly() async throws {
        let folder = dir.appendingPathComponent("photos")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = try TestImages.make("x.png", type: .png, in: folder)
        try Data("hi".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        let model = QueueViewModel()
        model.add([folder])
        #expect(model.items.map(\.name) == ["x.png"])
        await model.waitUntilIdle()
    }

    @Test func cancelWaitingItemSkipsIt() async throws {
        let first = try TestImages.make("1.png", type: .png, in: dir)
        let second = try TestImages.make("2.png", type: .png, in: dir)
        let model = QueueViewModel()
        model.add([first, second])
        model.cancel(model.items[1].id)
        await model.waitUntilIdle()

        #expect(model.items[1].state == .cancelled)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("2.jpg").path))
    }

    @Test func clearFinishedKeepsActiveItems() async throws {
        let input = try TestImages.make("d.png", type: .png, in: dir)
        let model = QueueViewModel()
        model.add([input])
        await model.waitUntilIdle()
        model.clearFinished()
        #expect(model.items.isEmpty)
    }
}
