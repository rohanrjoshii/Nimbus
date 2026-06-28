import AppKit
import Carbon.HIToolbox

/// Global hotkey (⌥⌘A) to show/hide the island. Uses Carbon RegisterEventHotKey,
/// which works system-wide WITHOUT Accessibility/Input-Monitoring permission.
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            guard let ctx = ctx else { return noErr }
            let mgr = Unmanaged<HotKeyManager>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { mgr.onTrigger?() }
            return noErr
        }, 1, &spec, selfPtr, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x4152434E) /* 'ARCN' */, id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_A),
                            UInt32(optionKey | cmdKey),
                            id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
