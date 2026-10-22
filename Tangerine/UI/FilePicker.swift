import AppKit
import UniformTypeIdentifiers

enum FilePicker {
    /// Returns the chosen files, or an empty array if the user cancels.
    @MainActor
    static func chooseFiles(types: [UTType], multiple: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = multiple
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.urls : []
    }
}
