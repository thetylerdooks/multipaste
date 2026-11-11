import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private var store: HistoryStore!
    private var clipboardMonitor: ClipboardMonitor!
    private var popout: PopoutController!

    private var statusItem: NSStatusItem?
    private var openMenuItem: NSMenuItem?
    private var pauseMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var accessibilityWindow: NSWindow?
    private var isUninstalling = false

    private let accessibility = AccessibilityMonitor.shared
    private var accessibilityObserver: AnyCancellable?
    private var lastAccessibilityPrompt: Date?
    /// A paste without Accessibility access re-prompts at most this often.
    private static let accessibilityPromptInterval: TimeInterval = 60

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        let historyStore = HistoryStore(settings: settings)
        store = historyStore

        let monitor = ClipboardMonitor(store: historyStore, settings: settings)
        monitor.start()
        clipboardMonitor = monitor

        let popoutController = PopoutController(store: historyStore)
        popoutController.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        popoutController.onRequestAccessibility = { [weak self] force in
            self?.requestAccessibility(force: force) ?? false
        }
        popout = popoutController

        setUpStatusItem()

        HotKeyManager.shared.handler = { [weak self] in
            self?.popout.toggle()
        }
        registerHotKey()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(hotKeyDidChange(_:)),
                                               name: .multipasteHotKeyChanged,
                                               object: nil)

        LoginItem.applyDefaultIfNeeded()

        accessibilityObserver = accessibility.$isTrusted
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                // Granted: the explanation window has done its job. Let the
                // publisher finish before closing a window that observes it.
                DispatchQueue.main.async {
                    self?.accessibilityWindow?.close()
                }
            }
        accessibility.start()

        if !settings.hasOnboarded {
            // Mark it now so closing the window with the red button also counts.
            settings.hasOnboarded = true
            // The welcome window explains Accessibility too, so it stands in
            // for the permission window on first run.
            showOnboarding()
        }
        // Every launch without access asks again, not just the first one: a
        // re-signed update can lose the permission even after onboarding.
        if !accessibility.isTrusted {
            requestAccessibility(force: true)
        }
    }

    // MARK: - Accessibility

    /// Shows the explanation window (or the welcome window, if it is open)
    /// and macOS's own Accessibility prompt. Unless `force` is set it does
    /// nothing if it already asked within `accessibilityPromptInterval`.
    /// Returns whether it asked.
    @discardableResult
    private func requestAccessibility(force: Bool) -> Bool {
        accessibility.start()
        guard !accessibility.isTrusted else { return false }
        if !force, let last = lastAccessibilityPrompt,
           Date().timeIntervalSince(last) < AppDelegate.accessibilityPromptInterval {
            return false
        }
        lastAccessibilityPrompt = Date()

        if let welcome = onboardingWindow, welcome.isVisible {
            present(welcome)
        } else {
            showAccessibilityWindow()
        }
        // After our window, so the system prompt ends up in front of it.
        DispatchQueue.main.async {
            AccessibilityPermission.requestWithPrompt()
        }
        return true
    }

    private func showAccessibilityWindow() {
        if accessibilityWindow == nil {
            let view = AccessibilityPromptView(monitor: accessibility,
                                               onClose: { [weak self] in
                                                   self?.accessibilityWindow?.close()
                                               })
            accessibilityWindow = makeWindow(title: "Allow Accessibility",
                                             size: AccessibilityPromptView.windowSize,
                                             content: NSHostingController(rootView: view))
        }
        present(accessibilityWindow)
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        HotKeyManager.shared.unregister()
        store?.flush()
        if isUninstalling {
            // Last thing we do: drop anything written to the defaults while quitting.
            wipePreferences()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Hot key

    private func registerHotKey() {
        HotKeyManager.shared.register(keyCode: settings.hotKeyCode,
                                      carbonModifiers: settings.hotKeyModifiers)
    }

    @objc private func hotKeyDidChange(_ notification: Notification) {
        registerHotKey()
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Multipaste") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "MP"
            }
            button.toolTip = "Multipaste"
        }

        let menu = NSMenu()
        menu.delegate = self

        let open = makeItem("Open Multipaste", #selector(openPopout(_:)))
        menu.addItem(open)
        openMenuItem = open

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem("Settings…", #selector(openSettings(_:)), key: ","))

        let pause = makeItem("Pause Recording", #selector(togglePause(_:)))
        menu.addItem(pause)
        pauseMenuItem = pause

        menu.addItem(makeItem("Clear History…", #selector(clearHistory(_:))))

        let login = makeItem("Launch at Login", #selector(toggleLaunchAtLogin(_:)))
        menu.addItem(login)
        launchAtLoginMenuItem = login

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem("About Multipaste", #selector(showAbout(_:))))
        menu.addItem(makeItem("Quit Multipaste", #selector(quit(_:)), key: "q"))

        item.menu = menu
        statusItem = item
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        openMenuItem?.title = "Open Multipaste  (\(settings.hotKeyDisplay))"
        pauseMenuItem?.state = settings.paused ? .on : .off
        if LoginItem.needsApproval {
            launchAtLoginMenuItem?.state = .mixed
        } else {
            launchAtLoginMenuItem?.state = LoginItem.isEnabled ? .on : .off
        }
    }

    // MARK: - Menu actions

    @objc private func openPopout(_ sender: Any?) {
        // Wait for the menu to finish closing before showing the panel.
        DispatchQueue.main.async { [weak self] in
            self?.popout.show()
        }
    }

    @objc private func openSettings(_ sender: Any?) {
        showSettings()
    }

    @objc private func togglePause(_ sender: Any?) {
        settings.paused.toggle()
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        if LoginItem.needsApproval {
            offerLoginItemApproval(canTurnOff: true)
            return
        }
        let enable = !LoginItem.isEnabled
        let changed = LoginItem.setEnabled(enable)
        if enable && LoginItem.needsApproval {
            offerLoginItemApproval(canTurnOff: false)
        } else if !changed {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Could not change Launch at Login"
            alert.informativeText = "Move Multipaste to the Applications folder and try again, or manage it in System Settings > General > Login Items."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// macOS has the login item switched off or awaiting approval in System Settings.
    private func offerLoginItemApproval(canTurnOff: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Launch at Login needs your approval"
        alert.informativeText = "Allow Multipaste under System Settings > General > Login Items so it can start when you log in."
        alert.addButton(withTitle: "Open Login Items Settings")
        if canTurnOff {
            alert.addButton(withTitle: "Turn Off")
        }
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            LoginItem.openLoginItemsSettings()
        } else if canTurnOff && response == .alertSecondButtonReturn {
            LoginItem.setEnabled(false)
        }
    }

    @objc private func clearHistory(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "This permanently deletes every saved item, including images. It cannot be undone."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearAll()
        }
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: AppInfo.tagline + "\nFully local. No network access. MIT License.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .version: AppInfo.build,
            .credits: credits
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // MARK: - Windows

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings,
                                    store: store,
                                    onShowOnboarding: { [weak self] in
                                        self?.showOnboarding()
                                    },
                                    onUninstall: { [weak self] in
                                        // Leave the button's action before showing the alert.
                                        DispatchQueue.main.async {
                                            self?.confirmUninstall()
                                        }
                                    })
            settingsWindow = makeWindow(title: "Multipaste Settings",
                                        size: SettingsView.windowSize,
                                        content: NSHostingController(rootView: view))
        }
        present(settingsWindow)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView(settings: settings,
                                      accessibility: accessibility,
                                      onDone: { [weak self] in
                                          self?.finishOnboarding()
                                      })
            onboardingWindow = makeWindow(title: "Welcome to Multipaste",
                                          size: OnboardingView.windowSize,
                                          content: NSHostingController(rootView: view))
        }
        present(onboardingWindow)
    }

    private func finishOnboarding() {
        settings.hasOnboarded = true
        onboardingWindow?.close()
    }

    private func makeWindow(title: String, size: NSSize, content: NSViewController) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = content
        window.setContentSize(size)
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    // MARK: - Uninstall

    private func confirmUninstall() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Uninstall Multipaste?"
        alert.informativeText = "This deletes your entire clipboard history (including saved images) and all Multipaste settings, turns off Launch at Login, and moves Multipaste to the Trash. It cannot be undone."
        // The first button is the default one (Return), so Cancel goes first.
        alert.addButton(withTitle: "Cancel")
        let uninstallButton = alert.addButton(withTitle: "Uninstall")
        uninstallButton.hasDestructiveAction = true
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        uninstall()
    }

    private func uninstall() {
        isUninstalling = true

        // Stop everything that could record or write again.
        clipboardMonitor?.stop()
        HotKeyManager.shared.unregister()
        popout?.hide()
        settingsWindow?.close()
        onboardingWindow?.close()
        accessibilityWindow?.close()

        LoginItem.setEnabled(false)
        store?.destroyStorage()
        wipePreferences()

        if !moveAppToTrash() {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Almost done"
            alert.informativeText = "Your clipboard history and settings were deleted, but Multipaste could not move itself to the Trash. To finish, drag Multipaste from the Applications folder to the Trash."
            alert.addButton(withTitle: "Quit Multipaste")
            alert.runModal()
        }
        NSApp.terminate(nil)
    }

    private func wipePreferences() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.tylerdooks.multipaste"
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: bundleID)
        defaults.synchronize()
        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(bundleID).plist")
        try? FileManager.default.removeItem(at: plist)
    }

    /// Returns false when the bundle is still where it was.
    private func moveAppToTrash() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        // Only ever trash a real .app bundle, never a bare build folder, and
        // not the temporary read-only copy macOS runs for quarantined apps.
        guard bundleURL.pathExtension == "app",
              !bundleURL.path.contains("/AppTranslocation/") else {
            return false
        }
        do {
            try FileManager.default.trashItem(at: bundleURL, resultingItemURL: nil)
            return true
        } catch {
            NSLog("Multipaste: could not move the app to the Trash: %@", error.localizedDescription)
            return false
        }
    }

    // MARK: - Main menu

    /// A menu-bar app has no visible main menu, but text fields still need one
    /// for the standard editing shortcuts (⌘X, ⌘C, ⌘V, ⌘A, ⌘Z) to work.
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(makeItem("About Multipaste", #selector(showAbout(_:))))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(makeItem("Settings…", #selector(openSettings(_:)), key: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(makeItem("Quit Multipaste", #selector(quit(_:)), key: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
