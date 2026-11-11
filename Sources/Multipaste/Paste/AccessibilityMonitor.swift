import AppKit
import ApplicationServices
import Combine

/// The one place that watches the Accessibility permission. While it is
/// missing it polls about once a second; as soon as macOS grants it, polling
/// stops and every view observing `isTrusted` updates. No restart needed.
final class AccessibilityMonitor: ObservableObject {
    static let shared = AccessibilityMonitor()

    @Published private(set) var isTrusted: Bool

    private var timer: Timer?

    private init() {
        isTrusted = AccessibilityPermission.isTrusted
    }

    /// Re-reads the permission and polls again if it is missing (for example
    /// after the user switched it off). Safe to call as often as you like.
    func start() {
        refresh()
    }

    private func refresh() {
        let trusted = AccessibilityPermission.isTrusted
        if trusted != isTrusted {
            isTrusted = trusted
        }
        if trusted {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            let pollTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.refresh()
            }
            // .common so it keeps firing while a menu is open or a window is dragged.
            RunLoop.main.add(pollTimer, forMode: .common)
            timer = pollTimer
        }
    }
}
