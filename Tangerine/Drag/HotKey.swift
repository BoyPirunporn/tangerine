import Carbon.HIToolbox

/// A system-wide shortcut (Control-Option-T). Carbon hotkeys need no extra permissions.
@MainActor
final class HotKey {
    nonisolated static let label = "⌃⌥T"

    private let action: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func register() {
        guard hotKeyRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        let id = EventHotKeyID(signature: OSType(0x544E4745), id: 1) // 'TNGE'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_T), UInt32(controlKey | optionKey), id,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }
}
