import AppKit
import Carbon

/// Registers one system-wide hot key through Carbon's RegisterEventHotKey.
/// This API needs no Accessibility or Input Monitoring permission.
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// Called on the main thread when the hot key is pressed.
    var handler: (() -> Void)?

    private(set) var isRegistered = false

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    fileprivate static let hotKeySignature: OSType = 0x4D50_5354 // "MPST"
    fileprivate static let hotKeyIdentifier: UInt32 = 1

    private init() {}

    @discardableResult
    func register(keyCode: Int, carbonModifiers: Int) -> Bool {
        unregister()
        installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: HotKeyManager.hotKeySignature,
                                     id: HotKeyManager.hotKeyIdentifier)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode),
                                         UInt32(carbonModifiers),
                                         hotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &ref)
        if status == noErr, let registered = ref {
            hotKeyRef = registered
            isRegistered = true
            return true
        }
        NSLog("Multipaste: could not register the global shortcut (status \(status))")
        return false
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        hotKeyRef = nil
        isRegistered = false
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(GetEventDispatcherTarget(),
                                         multipasteHotKeyEventHandler,
                                         1,
                                         &eventType,
                                         nil,
                                         &handlerRef)
        if status == noErr {
            eventHandlerRef = handlerRef
        } else {
            NSLog("Multipaste: could not install the hot key handler (status \(status))")
        }
    }
}

private func multipasteHotKeyEventHandler(_ callRef: EventHandlerCallRef?,
                                          _ event: EventRef?,
                                          _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)
    guard status == noErr else { return status }
    guard hotKeyID.signature == HotKeyManager.hotKeySignature,
          hotKeyID.id == HotKeyManager.hotKeyIdentifier else {
        return OSStatus(eventNotHandledErr)
    }
    DispatchQueue.main.async {
        HotKeyManager.shared.handler?()
    }
    return noErr
}
