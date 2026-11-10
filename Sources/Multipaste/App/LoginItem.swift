import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+).
enum LoginItem {
    private static let defaultAppliedKey = "didApplyDefaultLaunchAtLogin"

    /// True when Multipaste is registered as a login item, including when
    /// macOS still wants the user to approve it in System Settings.
    static var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    /// Registered, but switched off or not yet approved in System Settings > Login Items.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Returns true when the login item ended up in the requested state.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Multipaste: could not change the login item: %@", error.localizedDescription)
        }
        return isEnabled == enabled
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Multipaste starts at login by default. This registers the login item
    /// once; after that the user's choice is never overridden.
    static func applyDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: defaultAppliedKey) else { return }

        // A quarantined app runs from a random read-only path. Registering from
        // there would point at the wrong place, so wait until it has been moved.
        if Bundle.main.bundlePath.contains("/AppTranslocation/") {
            NSLog("Multipaste: running translocated; launch at login will be set up on a later launch")
            return
        }

        if setEnabled(true) {
            defaults.set(true, forKey: defaultAppliedKey)
        }
    }
}
