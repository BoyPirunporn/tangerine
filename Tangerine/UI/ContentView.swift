import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var model: QueueViewModel
    @State private var isTargeted = false
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsBar(model: model)
            Divider()
            if model.items.isEmpty {
                emptyState
            } else {
                List(model.items) { item in
                    QueueRow(item: item) { model.cancel(item.id) }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.tangerine, lineWidth: 3)
                    .background(Theme.tangerine.opacity(0.08))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls)
            return true
        } isTargeted: {
            isTargeted = $0
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: model.acceptedInputTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result { model.add(urls) }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Files…", systemImage: "plus") { showImporter = true }
                Menu("PDF Tools", systemImage: "doc.on.doc") {
                    Button("Merge into One PDF…") {
                        model.addMerge(FilePicker.chooseFiles(types: [.pdf] + Array(ImageFormats.readable), multiple: true))
                    }
                    Button("Split PDF into Pages…") {
                        model.addSplit(FilePicker.chooseFiles(types: [.pdf], multiple: true))
                    }
                }
                Button("Clear Finished", systemImage: "trash") { model.clearFinished() }
                    .disabled(!model.hasFinishedItems)
            }
        }
        .tint(Theme.tangerine)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 44))
                .foregroundStyle(Theme.tangerine)
            Text("Drop files or folders here").font(.title3)
            Button("Choose Files…") { showImporter = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(Theme.spacing)
        )
    }
}

#Preview {
    ContentView(model: QueueViewModel())
}
