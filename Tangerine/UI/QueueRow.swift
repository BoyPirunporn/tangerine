import AppKit
import SwiftUI

struct QueueRow: View {
    let item: QueueItem
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacing) {
            Image(systemName: item.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                status
                if let note = item.note {
                    Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var status: some View {
        switch item.state {
        case .waiting:
            Text("Waiting").font(.caption).foregroundStyle(.secondary)
        case .converting(let progress):
            ProgressView(value: progress).progressViewStyle(.linear)
        case .done(let url):
            Label(url.lastPathComponent, systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green).lineLimit(1)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.red).lineLimit(2)
        case .cancelled:
            Text("Cancelled").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var trailing: some View {
        if item.isActive {
            Button("Cancel", systemImage: "xmark.circle.fill", action: cancel)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        } else if case .done(let url) = item.state {
            Button("Show in Finder", systemImage: "magnifyingglass.circle") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }
}
