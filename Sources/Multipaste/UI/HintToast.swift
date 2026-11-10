import AppKit

/// A small, click-through message that fades in near the bottom of the screen.
/// Used when Multipaste copied something but cannot press Cmd+V itself.
final class HintToast {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(_ message: String, duration: TimeInterval = 4) {
        hide()

        let label = NSTextField(wrappingLabelWithString: message)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.isSelectable = false

        let maxTextWidth: CGFloat = 320
        let fitted = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: maxTextWidth, height: 400))
            ?? NSSize(width: maxTextWidth, height: 36)
        let textSize = NSSize(width: ceil(fitted.width), height: ceil(fitted.height))
        let size = NSSize(width: textSize.width + 36, height: textSize.height + 24)

        let toastPanel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        toastPanel.isReleasedWhenClosed = false
        toastPanel.isOpaque = false
        toastPanel.backgroundColor = .clear
        toastPanel.hasShadow = true
        toastPanel.level = .floating
        toastPanel.ignoresMouseEvents = true
        toastPanel.hidesOnDeactivate = false
        toastPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true

        label.frame = NSRect(x: 18, y: 12, width: textSize.width, height: textSize.height)
        effectView.addSubview(label)
        toastPanel.contentView = effectView

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        if let visible = screen?.visibleFrame {
            let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 90)
            toastPanel.setFrameOrigin(origin)
        } else {
            toastPanel.center()
        }

        toastPanel.orderFrontRegardless()
        panel = toastPanel

        let work = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
