import Foundation

enum AppInfo {
    static let name = "Multipaste"
    static let tagline = "Everything you copied, one shortcut away."

    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.5.3"
    }

    static var build: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "345"
    }
}

extension Notification.Name {
    /// Posted when the global shortcut was edited (or recording ended) and must be re-registered.
    static let multipasteHotKeyChanged = Notification.Name("MultipasteHotKeyChanged")
}
