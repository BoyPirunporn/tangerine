import AppKit

enum TriggerMode: String, CaseIterable, Sendable {
    case always
    case shift
    /// Pressing `HotKey.label` while a drag is in progress.
    case shortcut

    static let storageKey = "triggerMode"

    static var current: TriggerMode {
        TriggerMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .shift
    }

    func shouldShow(modifiers: NSEvent.ModifierFlags) -> Bool {
        switch self {
        case .always: true
        case .shift: modifiers.contains(.shift)
        case .shortcut: false // handled by the global hotkey, not by modifier keys
        }
    }

    var title: String {
        switch self {
        case .always: String(localized: "Always when dragging a file")
        case .shift: String(localized: "Only while holding Shift")
        case .shortcut: String(localized: "Only when pressing \(HotKey.label)")
        }
    }
}
