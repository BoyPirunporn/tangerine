import AppKit
import SwiftUI

struct SettingsBar: View {
    @Bindable var model: QueueViewModel

    var body: some View {
        HStack(spacing: Theme.spacing) {
            Picker("Convert to", selection: $model.targetType) {
                ForEach(model.formats, id: \.self) { type in
                    Text(QueueViewModel.label(for: type)).tag(type)
                }
            }
            .fixedSize()

            if model.usesQuality {
                HStack {
                    Text("Quality")
                    Slider(value: $model.quality, in: 0.1...1)
                        .frame(width: 110)
                        .accessibilityLabel("Quality")
                    Text(model.quality, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }

            Spacer()

            Button(folderTitle, systemImage: "folder", action: chooseFolder)
                .help("Where converted files are saved")
            if model.outputDirectory != nil {
                Button("Use original folder", systemImage: "xmark.circle") {
                    model.outputDirectory = nil
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        .padding(Theme.spacing)
    }

    private var folderTitle: String {
        model.outputDirectory?.lastPathComponent ?? String(localized: "Next to original")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Choose")
        if panel.runModal() == .OK {
            model.outputDirectory = panel.url
        }
    }
}
