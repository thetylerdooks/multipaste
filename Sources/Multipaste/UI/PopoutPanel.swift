import AppKit
import QuartzCore
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
        // The controller runs its own pop animation.
        animationBehavior = .none
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
    /// Asks the app to prompt for Accessibility. `force` skips the rate limit;
    /// returns false when the prompt was skipped because it was shown recently.
    var onRequestAccessibility: ((_ force: Bool) -> Bool)?

    private let store: HistoryStore
    private let panel: PopoutPanel
    private let toast = HintToast()
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private weak var searchField: NSTextField?

    /// The rounded, vibrant bubble. Its layer is what scales during the pop animation.
    private let effectView: NSVisualEffectView
    /// Logical state. The panel itself stays on screen a moment longer while it animates out.
    private var isShown = false
    /// Bumped on every show / hide so a stale close animation can never hide a reopened panel.
    private var animationGeneration = 0
    /// Point (in the bubble's own coordinates) the pop grows out of: the spot nearest the pointer.
    private var popAnchor = CGPoint.zero

    private static let popAnimationKey = "multipaste.pop"
    private static let closeDuration: TimeInterval = 0.12
    /// ⌘V is sent no sooner than this after the panel closes...
    private static let minimumPasteDelay: TimeInterval = 0.13
    /// ...and no later than this, even if the target app never reports itself frontmost.
    private static let maximumPasteDelay: TimeInterval = 0.6

    var isVisible: Bool { isShown }

    init(store: HistoryStore) {
        let frame = NSRect(origin: .zero, size: PopoutController.panelSize)
        self.store = store
        self.model = PopoutViewModel(store: store)
        self.panel = PopoutPanel(contentSize: PopoutController.panelSize)
        self.effectView = NSVisualEffectView(frame: frame)
        super.init()

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

        // The bubble sits in a transparent container that always fills the
        // window, so the window frame never changes while the bubble scales.
        let container = NSView(frame: frame)
        container.wantsLayer = true
        effectView.autoresizingMask = [.width, .height]
        container.addSubview(effectView)
        panel.contentView = container

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
            self?.hide(animated: false)
            self?.onOpenSettings?()
        }
        model.onRequestAccessibility = { [weak self] in
            self?.hide(animated: false)
            _ = self?.onRequestAccessibility?(true)
        }
    }

    // MARK: - Showing and hiding

    func toggle() {
        if isShown {
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

        // Cancel whatever animation (opening or closing) is still running.
        animationGeneration += 1
        isShown = true
        effectView.layer?.removeAnimation(forKey: PopoutController.popAnimationKey)
        panel.ignoresMouseEvents = false

        model.prepareForOpen()
        positionAtPointer()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        // Keyboard focus is immediate; only the looks are animated.
        panel.makeKey()
        panel.invalidateShadow()
        installKeyMonitor()
        focusSearchField(selectAll: false)
        animateIn()

        DispatchQueue.main.async { [weak self] in
            self?.focusSearchField(selectAll: false)
        }
    }

    /// Closes the popout. A paste passes `animated: false`: the panel must be
    /// gone at once so the previous app has the keyboard when ⌘V is sent.
    func hide(animated: Bool = true) {
        // Ordering out makes the panel resign key, which calls hide() again.
        guard isShown else { return }
        isShown = false
        animationGeneration += 1
        removeKeyMonitor()

        guard animated, panel.isVisible else {
            orderOutNow()
            return
        }

        // No more clicks on a panel that is on its way out.
        panel.ignoresMouseEvents = true
        animateOut()

        let generation = animationGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + PopoutController.closeDuration) { [weak self] in
            guard let controller = self,
                  controller.animationGeneration == generation,
                  !controller.isShown else { return }
            controller.orderOutNow()
        }
    }

    private func orderOutNow() {
        if panel.isVisible {
            panel.orderOut(nil)
        }
        effectView.layer?.removeAnimation(forKey: PopoutController.popAnimationKey)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
    }

    // MARK: - Pop animation

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Fade in, plus a springy scale-up out of the pointer unless Reduce Motion is on.
    private func animateIn() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.16
        panel.animator().alphaValue = 1
        NSAnimationContext.endGrouping()

        guard !reduceMotion, let layer = effectView.layer else { return }
        // Roughly SwiftUI's .spring(response: 0.25, dampingFraction: 0.72).
        let spring = CASpringAnimation(keyPath: "transform")
        spring.fromValue = NSValue(caTransform3D: scaleTransform(0.85, for: layer))
        spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        spring.mass = 1
        spring.stiffness = 632
        spring.damping = 36
        spring.initialVelocity = 0
        spring.duration = min(spring.settlingDuration, 0.6)
        layer.add(spring, forKey: PopoutController.popAnimationKey)
    }

    /// Quick fade out, plus a small scale-down unless Reduce Motion is on.
    private func animateOut() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = PopoutController.closeDuration
        panel.animator().alphaValue = 0
        NSAnimationContext.endGrouping()

        guard !reduceMotion, let layer = effectView.layer else { return }
        let shrink = CABasicAnimation(keyPath: "transform")
        shrink.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
        shrink.toValue = NSValue(caTransform3D: scaleTransform(0.9, for: layer))
        shrink.duration = PopoutController.closeDuration
        shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
        // Stay small until the panel is ordered out (the animation is removed then).
        shrink.fillMode = .forwards
        shrink.isRemovedOnCompletion = false
        layer.add(shrink, forKey: PopoutController.popAnimationKey)
    }

    /// A scale that keeps `popAnchor` fixed. Only ever used inside an explicit
    /// animation, so the layer's own (AppKit-managed) geometry is never changed.
    private func scaleTransform(_ scale: CGFloat, for layer: CALayer) -> CATransform3D {
        let bounds = layer.bounds
        let originX = bounds.minX + layer.anchorPoint.x * bounds.width
        let originY = bounds.minY + layer.anchorPoint.y * bounds.height
        let dx = popAnchor.x - originX
        let dy = popAnchor.y - originY
        var transform = CATransform3DMakeTranslation(dx, dy, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        transform = CATransform3DTranslate(transform, -dx, -dy, 0)
        return transform
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
            popAnchor = CGPoint(x: size.width / 2, y: size.height / 2)
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

        // The pointer's position relative to the final frame, clamped onto the
        // panel: the nearest corner (or edge point) after any flip or shift.
        popAnchor = CGPoint(x: max(0, min(mouse.x - x, size.width)),
                            y: max(0, min(mouse.y - y, size.height)))
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
        // Not animated: the paste must not wait for (or race with) the close animation.
        hide(animated: false)
        // hide() does nothing if the panel was already closing; make sure it is gone.
        orderOutNow()

        if let app = target, !app.isTerminated {
            _ = app.activate(options: [])
        }

        whenReadyToPaste(into: target, since: Date()) { [weak self] in
            guard let controller = self else { return }
            if AccessibilityPermission.isTrusted {
                PasteService.sendPasteKeystroke()
            } else {
                // The item is on the clipboard either way. Ask for access again
                // (rate-limited); in between, the toast is enough.
                let prompted = controller.onRequestAccessibility?(false) ?? false
                if !prompted {
                    controller.toast.show("Copied. Press ⌘V to paste.\nAllow Accessibility in Multipaste Settings to paste automatically.")
                }
            }
            guard let id = itemID else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.store.moveToTop(id: id)
            }
        }
    }

    /// Runs `action` once the panel is off screen and `target` (the app the
    /// paste is for) is frontmost, so ⌘V lands in the right app. Waits at
    /// least `minimumPasteDelay` and stops waiting after `maximumPasteDelay`.
    private func whenReadyToPaste(into target: NSRunningApplication?, since start: Date, _ action: @escaping () -> Void) {
        let elapsed = Date().timeIntervalSince(start)
        let targetIsFrontmost: Bool
        if let app = target, !app.isTerminated {
            targetIsFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        } else {
            // Pasting into one of our own windows, or the app has quit.
            targetIsFrontmost = true
        }
        let ready = targetIsFrontmost && !panel.isVisible && elapsed >= PopoutController.minimumPasteDelay
        if ready || elapsed >= PopoutController.maximumPasteDelay {
            action()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.whenReadyToPaste(into: target, since: start, action)
        }
    }
}
