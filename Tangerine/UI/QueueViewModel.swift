import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class QueueViewModel {
    private(set) var items: [QueueItem] = []
    var targetType: UTType = .jpeg
    var quality = 0.85
    /// `nil` means "next to the original file".
    var outputDirectory: URL?

    /// Called once each time the queue runs dry, with the final state of every job in that run.
    @ObservationIgnored var onBatchFinished: (([QueueItem.State]) -> Void)?

    let registry: ConverterRegistry
    private var running: [UUID: Task<URL, Error>] = [:]
    private var worker: Task<Void, Never>?
    private var batchStates: [QueueItem.State] = []

    init(registry: ConverterRegistry = .standard) {
        self.registry = registry
    }

    static let lossyTypes: Set<UTType> = [.jpeg, .heic, ImageFormats.avif]

    /// Order shown in pickers and on the radial menu.
    static let displayOrder: [UTType] = [
        .jpeg, .png, .heic, ImageFormats.avif, .tiff, .gif, .bmp, .pdf, WordFormats.docx, .plainText, .html,
        MediaFormats.mp4, MediaFormats.mov, MediaFormats.mkv, MediaFormats.m4a, .mp3, .wav, MediaFormats.flac,
    ]

    var formats: [UTType] { Self.ordered(registry.allOutputs) }

    var usesQuality: Bool { Self.lossyTypes.contains(targetType) }

    var acceptedInputTypes: [UTType] {
        registry.converters.flatMap(\.supportedInputs) + [.folder]
    }

    var hasFinishedItems: Bool { items.contains { !$0.isActive } }

    static func label(for type: UTType) -> String {
        type == .jpeg ? "JPG" : (type.preferredFilenameExtension ?? type.identifier).uppercased()
    }

    static func ordered(_ types: some Collection<UTType>) -> [UTType] {
        func rank(_ type: UTType) -> Int { displayOrder.firstIndex(of: type) ?? .max }
        return types.sorted { (rank($0), label(for: $0)) < (rank($1), label(for: $1)) }
    }

    // MARK: Adding

    /// Files are queued as dropped; folders are expanded to the files we can convert.
    /// `type` overrides the format picked in the window (used by the radial menu).
    func add(_ urls: [URL], as type: UTType? = nil) {
        let target = type ?? targetType
        for url in urls {
            for file in Self.files(in: url, accepting: { registry.converter(from: $0, to: target) != nil }) {
                let inputType = try? file.resourceValues(forKeys: [.contentTypeKey]).contentType
                items.append(QueueItem(
                    work: .convert(ConversionJob(
                        input: file,
                        outputType: target,
                        outputDirectory: outputDirectory ?? file.deletingLastPathComponent(),
                        quality: quality
                    )),
                    note: ConversionLimits.note(from: inputType, to: target)
                ))
            }
        }
        startWorkerIfNeeded()
    }

    /// PDFs and images, merged in the order given.
    func addMerge(_ urls: [URL]) {
        guard urls.count >= 2 else { return }
        let directory = outputDirectory ?? urls[0].deletingLastPathComponent()
        items.append(QueueItem(work: .merge(urls, outputDirectory: directory)))
        startWorkerIfNeeded()
    }

    func addSplit(_ urls: [URL]) {
        for url in urls {
            items.append(QueueItem(work: .split(url, outputDirectory: outputDirectory ?? url.deletingLastPathComponent())))
        }
        startWorkerIfNeeded()
    }

    private static func files(in url: URL, accepting: (UTType) -> Bool) -> [URL] {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDirectory else { return [url] }
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentTypeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        var result: [URL] = []
        while let file = enumerator?.nextObject() as? URL {
            let values = try? file.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
            if values?.isRegularFile == true, let type = values?.contentType, accepting(type) {
                result.append(file)
            }
        }
        return result.sorted { $0.path < $1.path }
    }

    // MARK: Control

    func cancel(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        switch items[index].state {
        case .waiting: items[index].state = .cancelled
        case .converting: running[id]?.cancel()
        default: break
        }
    }

    func cancelAll() {
        for item in items where item.isActive { cancel(item.id) }
    }

    func clearFinished() {
        items.removeAll { !$0.isActive }
    }

    func waitUntilIdle() async {
        await worker?.value
    }

    // MARK: Processing (one job at a time)

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while let self, let next = self.items.first(where: { $0.state == .waiting }) {
                await self.run(next)
            }
            self?.finishBatch()
            self?.worker = nil
        }
    }

    private func finishBatch() {
        let states = batchStates
        batchStates = []
        if !states.isEmpty { onBatchFinished?(states) }
    }

    private func run(_ item: QueueItem) async {
        let id = item.id
        setState(id, .converting(0))
        let report: @Sendable (Double) -> Void = { [weak self] progress in
            Task { @MainActor in self?.setProgress(id, progress) }
        }
        let task = Task { [registry] in
            switch item.work {
            case .convert(let job):
                try await registry.convert(job, progress: report)
            case .merge(let urls, let directory):
                try await PDFTools.merge(urls, outputDirectory: directory, progress: report)
            case .split(let url, let directory):
                try await PDFTools.split(url, outputDirectory: directory, progress: report)
            }
        }
        running[id] = task
        let result = await task.result
        running[id] = nil
        switch result {
        case .success(let url):
            setState(id, .done(url))
            batchStates.append(.done(url))
        case .failure(is CancellationError):
            setState(id, .cancelled)
        case .failure(let error):
            setState(id, .failed(error.localizedDescription))
            batchStates.append(.failed(error.localizedDescription))
        }
    }

    private func setState(_ id: UUID, _ state: QueueItem.State) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = state
    }

    private func setProgress(_ id: UUID, _ progress: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              case .converting = items[index].state else { return }
        items[index].state = .converting(progress)
    }
}
