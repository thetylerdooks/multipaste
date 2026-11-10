import AppKit
import ApplicationServices

/// Writes history items back to the pasteboard and presses Cmd+V for the user.
enum PasteService {
    /// Marker type added to everything Multipaste writes itself, so the
    /// clipboard monitor does not record it again as new content.
    static let ownMarkerType = NSPasteboard.PasteboardType("com.tylerdooks.multipaste.own-write")

    /// Puts a history item on the general pasteboard. Returns false if the
    /// item's data is gone (for example a deleted image file).
    static func copy(_ item: ClipboardItem, store: HistoryStore) -> Bool {
        let pasteboard = NSPasteboard.general

        switch item.kind {
        case .image:
            guard let png = store.imageData(for: item) else { return false }
            var types: [NSPasteboard.PasteboardType] = [.png]
            let tiff = NSImage(data: png)?.tiffRepresentation
            if tiff != nil { types.append(.tiff) }
            types.append(ownMarkerType)
            pasteboard.declareTypes(types, owner: nil)
            pasteboard.setData(png, forType: .png)
            if let tiffData = tiff {
                pasteboard.setData(tiffData, forType: .tiff)
            }
            pasteboard.setString("1", forType: ownMarkerType)
            return true

        case .file:
            let urls = (item.filePaths ?? []).map { NSURL(fileURLWithPath: $0) }
            guard !urls.isEmpty else { return false }
            pasteboard.clearContents()
            pasteboard.writeObjects(urls)
            pasteboard.addTypes([ownMarkerType], owner: nil)
            pasteboard.setString("1", forType: ownMarkerType)
            return true

        case .text, .link, .color, .code:
            guard let text = item.text else { return false }
            var types: [NSPasteboard.PasteboardType] = [.string]
            if item.rtf != nil { types.append(.rtf) }
            types.append(ownMarkerType)
            pasteboard.declareTypes(types, owner: nil)
            pasteboard.setString(text, forType: .string)
            if let rtf = item.rtf {
                pasteboard.setData(rtf, forType: .rtf)
            }
            pasteboard.setString("1", forType: ownMarkerType)
            return true
        }
    }

    /// Puts a plain string (emoji, kaomoji, symbol) on the general pasteboard.
    static func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string, ownMarkerType], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("1", forType: ownMarkerType)
    }

    /// Synthesizes Cmd+V in the frontmost app. Requires Accessibility permission.
    static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let virtualKeyV: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

/// The Accessibility permission is only used to press Cmd+V on the user's behalf.
enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that offers to open the Accessibility settings.
    static func requestWithPrompt() {
        // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
