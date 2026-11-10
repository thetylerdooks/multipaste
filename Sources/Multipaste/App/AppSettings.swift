import Foundation
import Combine

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultIgnoredApps = ["Keychain Access", "1Password", "Bitwarden"]
    static let defaultHotKeyCode = 9            // V
    static let defaultHotKeyModifiers = 768     // Carbon cmdKey (256) | shiftKey (512)

    private enum Key {
        static let maxItems = "maxItems"
        static let maxAgeDays = "maxAgeDays"
        static let maxImageMB = "maxImageMB"
        static let ignoredApps = "ignoredApps"
        static let paused = "paused"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hasOnboarded = "hasOnboarded"
    }

    private let defaults = UserDefaults.standard

    /// Maximum number of history items kept.
    @Published var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: Key.maxItems) }
    }

    /// Items older than this many days are removed. 0 means "Forever".
    @Published var maxAgeDays: Int {
        didSet { defaults.set(maxAgeDays, forKey: Key.maxAgeDays) }
    }

    /// Images larger than this (in MB) are not recorded.
    @Published var maxImageMB: Int {
        didSet { defaults.set(maxImageMB, forKey: Key.maxImageMB) }
    }

    /// App names (or bundle identifiers) whose copies are never recorded.
    @Published var ignoredApps: [String] {
        didSet { defaults.set(ignoredApps, forKey: Key.ignoredApps) }
    }

    @Published var paused: Bool {
        didSet { defaults.set(paused, forKey: Key.paused) }
    }

    /// Virtual key code of the global shortcut.
    @Published var hotKeyCode: Int {
        didSet { defaults.set(hotKeyCode, forKey: Key.hotKeyCode) }
    }

    /// Carbon modifier mask of the global shortcut.
    @Published var hotKeyModifiers: Int {
        didSet { defaults.set(hotKeyModifiers, forKey: Key.hotKeyModifiers) }
    }

    @Published var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Key.hasOnboarded) }
    }

    private init() {
        let stored = UserDefaults.standard
        maxItems = (stored.object(forKey: Key.maxItems) as? Int) ?? 200
        maxAgeDays = (stored.object(forKey: Key.maxAgeDays) as? Int) ?? 30
        maxImageMB = (stored.object(forKey: Key.maxImageMB) as? Int) ?? 10
        ignoredApps = (stored.array(forKey: Key.ignoredApps) as? [String]) ?? AppSettings.defaultIgnoredApps
        paused = stored.bool(forKey: Key.paused)
        hotKeyCode = (stored.object(forKey: Key.hotKeyCode) as? Int) ?? AppSettings.defaultHotKeyCode
        hotKeyModifiers = (stored.object(forKey: Key.hotKeyModifiers) as? Int) ?? AppSettings.defaultHotKeyModifiers
        hasOnboarded = stored.bool(forKey: Key.hasOnboarded)
    }

    var hotKeyDisplay: String {
        KeyCombo.displayString(keyCode: hotKeyCode, carbonModifiers: hotKeyModifiers)
    }

    /// True when copies made by this app should not be recorded.
    func isIgnored(appName: String?, bundleID: String?) -> Bool {
        let name = (appName ?? "").lowercased()
        let bundle = (bundleID ?? "").lowercased()
        for entry in ignoredApps {
            let needle = entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if needle.isEmpty { continue }
            if !name.isEmpty && name.contains(needle) { return true }
            if !bundle.isEmpty && bundle == needle { return true }
        }
        return false
    }
}
