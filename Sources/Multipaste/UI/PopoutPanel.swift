import AppKit
import SwiftUI

/// Borderless floating panel. It can become key (so the search field gets
/// keystrokes) but, being non-activating, leaves the previous app frontmost.
final class PopoutPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init(contentSize: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: contentSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: true)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Clicking anywhere outside the panel makes it lose key status.
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

/// Owns the popout panel: positioning at the pointer, keyboard handling and
/// the paste flow.
final class PopoutController: NSObject {
    static let panelSize = NSSize(width: 360, height: 460)

    let model: PopoutViewModel
    var onOpenSettings: (() -> Void)?
    var onShowOnboarding: (() -> Void)?

    private let store: HistoryStore
    private let panel: PopoutPanel
    private let toast = HintToast()
    private var keyMonitor: Any?
    private var isHiding = false
    private var previousApp: NSRunningApplication?
    private weak var searchField: NSTextField?

    var isVisible: Bool { panel.isVisible }

    init(store: HistoryStore) {
        self.store = store
        self.model = PopoutViewModel(store: store)
        self.panel = PopoutPanel(contentSize: PopoutController.panelSize)
        super.init()

        let frame = NSRect(origin: .zero, size: PopoutController.panelSize)
        let effectView = NSVisualEffectView(frame: frame)
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: PopoutView(model: model, store: store))
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)
        panel.contentView = effectView

        panel.onResignKey = { [weak self] in
            self?.hide()
        }
        model.onPasteItem = { [weak self] item in
            self?.paste(item: item)
        }
        model.onPasteText = { [weak self] text in
            self?.paste(text: text)
        }
        model.onClose = { [weak self] in
            self?.hide()
        }
        model.onOpenSettings = { [weak self] in
            self?.hide()
            self?.onOpenSettings?()
        }
        model.onShowOnboarding = { [weak self] in
            self?.hide()
            self?.onShowOnboarding?()
        }
    }

    // MARK: - Showing and hiding

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        // Remember who was frontmost so the paste lands there.
        let frontmost = NSWorkspace.shared.frontmostApplication
        if let app = frontmost, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = app
        } else {
            // Opened while one of our own windows is frontmost: paste stays here.
            previousApp = nil
        }

        model.prepareForOpen()
        positionAtPointer()
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.invalidateShadow()
        installKeyMonitor()

        DispatchQueue.main.async { [weak self] in
            self?.focusSearchField(selectAll: false)
        }
    }

    func hide() {
        guard !isHiding else { return }
        isHiding = true
        removeKeyMonitor()
        if panel.isVisible {
            panel.orderOut(nil)
        }
        isHiding = false
    }

    /// Opens the panel at the mouse pointer, flipping / shifting so it stays
    /// fully inside the visible frame of the screen that contains the pointer.
    private func positionAtPointer() {
        let mouse = NSEvent.mouseLocation
        let size = PopoutController.panelSize
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
            panel.setContentSize(size)
            panel.center()
            return
        }

        let gap: CGFloat = 4
        var x = mouse.x + gap
        var y = mouse.y - size.height - gap

        if x + size.width > visible.maxX {
            x = mouse.x - size.width - gap
        }
        if y < visible.minY {
            y = mouse.y + gap
        }

        x = max(visible.minX + gap, min(x, visible.maxX - size.width - gap))
        y = max(visible.minY + gap, min(y, visible.maxY - size.height - gap))

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let controller = self else { return event }
            return controller.handleKeyDown(event)
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
    }

    /// Returns nil when the event was consumed.
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard panel.isVisible, event.window === panel else { return event }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)
        let keyCode = Int(event.keyCode)

        // Let an input method finish composing before we steal Return / arrows.
        if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() {
            return event
        }

        switch keyCode {
        case 53: // Esc
            hide()
            return nil
        case 36, 76: // Return, keypad Enter
            model.activateSelection()
            return nil
        case 48: // Tab
            model.cycleTab(forward: !flags.contains(.shift))
            return nil
        case 125: // Down
            model.moveSelection(dx: 0, dy: 1)
            return nil
        case 126: // Up
            model.moveSelection(dx: 0, dy: -1)
            return nil
        case 123: // Left
            if model.tab.isGrid && !command && !option {
                model.moveSelection(dx: -1, dy: 0)
                return nil
            }
        case 124: // Right
            if model.tab.isGrid && !command && !option {
                model.moveSelection(dx: 1, dy: 0)
                return nil
            }
        default:
            break
        }

        if command && !option && !control {
            let characters = event.charactersIgnoringModifiers ?? ""
            if let digit = Int(characters), digit >= 1, digit <= 9 {
                model.quickPaste(digit - 1)
                return nil
            }
            if characters == "," {
                model.onOpenSettings?()
                return nil
            }
            // Cmd+W / Cmd+Q close the popout instead of quitting Multipaste.
            if characters.lowercased() == "w" || characters.lowercased() == "q" {
                hide()
                return nil
            }
        }

        // Anything else is typing: make sure it reaches the search field.
        if !(panel.firstResponder is NSTextView) {
            focusSearchField(selectAll: false)
        }
        return event
    }

    private func focusSearchField(selectAll: Bool) {
        if searchField == nil, let root = panel.contentView {
            searchField = PopoutController.findTextField(in: root)
        }
        guard let field = searchField else { return }
        if panel.firstResponder is NSTextView, field.currentEditor() != nil {
            return
        }
        panel.makeFirstResponder(field)
        if !selectAll {
            let end = field.stringValue.utf16.count
            field.currentEditor()?.selectedRange = NSRange(location: end, length: 0)
        }
    }

    private static func findTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable {
            return field
        }
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Pasting

    private func paste(item: ClipboardItem) {
        guard PasteService.copy(item, store: store) else {
            NSSound.beep()
            return
        }
        // The history is deliberately NOT touched here. Reordering it publishes a
        // change that re-renders the popout while it is closing, and that was the
        // only difference from the emoji path, which pastes reliably. The item is
        // moved to the top once the keystroke has been sent.
        finishPaste(movingToTop: item.id)
    }

    private func paste(text: String) {
        PasteService.copy(text: text)
        finishPaste(movingToTop: nil)
    }

    /// The one paste routine shared by history items and emoji / kaomoji / symbols.
    private func finishPaste(movingToTop itemID: UUID?) {
        let target = previousApp
        hide()

        if let app = target, !app.isTerminated {
            _ = app.activate(options: [])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
            if AccessibilityPermission.isTrusted {
                PasteService.sendPasteKeystroke()
            } else {
                self?.toast.show("Copied. Press ⌘V to paste.\nAllow Accessibility in Multipaste Settings to paste automatically.")
            }
            guard let id = itemID else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.store.moveToTop(id: id)
            }
        }
    }
}
