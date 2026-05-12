import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey via Carbon and invokes a closure when fired.
/// Use Carbon `kVK_*` key codes and Carbon modifier flags (`cmdKey`, `shiftKey`, …).
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var registeredKeyCode: UInt32 = 0
    private var registeredModifiers: UInt32 = 0

    var onTrigger: (() -> Void)?

    private static let hotKeySignature: OSType = {
        // Four-char code 'GHWR'.
        let chars: [UInt8] = [0x47, 0x48, 0x57, 0x52]
        return chars.reduce(0) { ($0 << 8) | OSType($1) }
    }()

    private init() {}

    /// Register the given key code + modifier mask. If already registered with identical
    /// values this is a no-op. Re-registering with different values cleanly replaces
    /// the previous registration.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        if hotKeyRef != nil &&
            keyCode == registeredKeyCode &&
            modifiers == registeredModifiers {
            return true
        }
        unregister()

        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRef = ref
            registeredKeyCode = keyCode
            registeredModifiers = modifiers
            return true
        }
        NSLog("HotkeyManager.register failed (status=%d)", status)
        return false
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        registeredKeyCode = 0
        registeredModifiers = 0
    }

    private func installHandlerIfNeeded() {
        if handlerRef != nil { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, theEvent, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.onTrigger?() }
                _ = theEvent
                return noErr
            },
            1,
            &spec,
            userInfo,
            &ref
        )
        if status == noErr {
            handlerRef = ref
        } else {
            NSLog("HotkeyManager.installHandler failed (status=%d)", status)
        }
    }
}
