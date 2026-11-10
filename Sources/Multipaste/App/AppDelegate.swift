import AppKit
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
        popoutController.onShowOnboarding = { [weak self] in
            self?.showOnboarding()
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

        if !settings.hasOnboarded {
            // Mark it now so closing the window with the red button also counts.
            settings.hasOnboarded = true
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        HotKeyManager.shared.unregister()
        store?.flush()
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
        launchAtLoginMenuItem?.state = LoginItem.isEnabled ? .on : .off
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
        let enable = !LoginItem.isEnabled
        if !LoginItem.setEnabled(enable) {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Could not change Launch at Login"
            alert.informativeText = "Move Multipaste to the Applications folder and try again, or manage it in System Settings > General > Login Items."
            alert.addButton(withTitle: "OK")
            alert.runModal()
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
