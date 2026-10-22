import Foundation

struct QueueItem: Identifiable, Sendable {
    enum Work: Sendable {
        case convert(ConversionJob)
        case merge([URL], outputDirectory: URL)
        case split(URL, outputDirectory: URL)
    }

    enum State: Equatable, Sendable {
        case waiting
        case converting(Double)
        case done(URL)
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let work: Work
    var state: State = .waiting
    /// What this conversion can't preserve, if anything.
    var note: String?

    var name: String {
        switch work {
        case .convert(let job): job.input.lastPathComponent
        case .merge(let urls, _): String(localized: "Merge \(urls.count) files into one PDF")
        case .split(let url, _): String(localized: "Split \(url.lastPathComponent)")
        }
    }

    var systemImage: String {
        switch work {
        case .convert: "photo"
        case .merge: "doc.on.doc"
        case .split: "scissors"
        }
    }

    var isActive: Bool {
        switch state {
        case .waiting, .converting: true
        default: false
        }
    }
}
