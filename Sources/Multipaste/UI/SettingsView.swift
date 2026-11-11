import AppKit
import Combine
import SwiftUI

struct SettingsView: View {
    static let windowSize = NSSize(width: 500, height: 600)

    @ObservedObject var settings: AppSettings
    @ObservedObject var store: HistoryStore
    var onShowOnboarding: () -> Void
    var onUninstall: () -> Void

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginNeedsApproval = LoginItem.needsApproval
    @ObservedObject private var accessibility = AccessibilityMonitor.shared
    @State private var newIgnoredApp = ""
    @State private var confirmClear = false

    private let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private static let itemLimits = [50, 100, 200, 500, 1000]
    private static let imageLimits = [1, 5, 10, 25, 50]

    var body: some View {
        Form {
            shortcutSection
            generalSection
            historySection
            ignoredAppsSection
            permissionSection
            aboutSection
            uninstallSection
        }
        .formStyle(.grouped)
        .frame(width: SettingsView.windowSize.width, height: SettingsView.windowSize.height)
        .onReceive(refreshTimer) { _ in
            launchAtLogin = LoginItem.isEnabled
            loginNeedsApproval = LoginItem.needsApproval
            // Also notices the permission being switched off while Settings is open.
            accessibility.start()
        }
        .onChange(of: settings.maxItems) { _ in
            store.prune()
        }
        .onChange(of: settings.maxAgeDays) { _ in
            store.prune()
        }
        .alert("Clear clipboard history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) {
                store.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every saved item, including images. It cannot be undone.")
        }
    }

    // MARK: - Sections

    private var shortcutSection: some View {
        Section("Shortcut") {
            HStack(alignment: .top) {
                Text("Open Multipaste")
                Spacer()
                HotKeyRecorderView(settings: settings)
            }
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: launchAtLoginBinding)
            if loginNeedsApproval {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Needs approval in System Settings.")
                        .font(.system(size: 12))
                    Spacer()
                    Button("Open Login Items Settings") {
                        LoginItem.openLoginItemsSettings()
                    }
                }
            }
            Toggle("Pause recording", isOn: $settings.paused)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                LoginItem.setEnabled(newValue)
                launchAtLogin = LoginItem.isEnabled
                loginNeedsApproval = LoginItem.needsApproval
            }
        )
    }

    private var historySection: some View {
        Section("History") {
            Picker("Keep at most", selection: $settings.maxItems) {
                ForEach(SettingsView.itemLimits, id: \.self) { limit in
                    Text("\(limit) items").tag(limit)
                }
            }
            Picker("Remove items after", selection: $settings.maxAgeDays) {
                Text("1 day").tag(1)
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("1 year").tag(365)
                Text("Forever").tag(0)
            }
            Picker("Largest image to keep", selection: $settings.maxImageMB) {
                ForEach(SettingsView.imageLimits, id: \.self) { limit in
                    Text("\(limit) MB").tag(limit)
                }
            }
            HStack {
                Text("\(store.items.count) items saved")
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear History…") {
                    confirmClear = true
                }
                .disabled(store.items.isEmpty)
            }
        }
    }

    private var ignoredAppsSection: some View {
        Section {
            ForEach(settings.ignoredApps, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Button(action: { removeIgnoredApp(name) }) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
            }
            HStack {
                TextField("App name", text: $newIgnoredApp, prompt: Text("App name, e.g. Notes"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addIgnoredApp()
                    }
                Button("Add") {
                    addIgnoredApp()
                }
                    .disabled(newIgnoredApp.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Defaults") {
                    settings.ignoredApps = AppSettings.defaultIgnoredApps
                }
            }
        } header: {
            Text("Ignored apps")
        } footer: {
            Text("Copies made while one of these apps is frontmost are never recorded. Passwords that apps mark as concealed are always skipped.")
        }
    }

    private var permissionSection: some View {
        Section("Accessibility") {
            HStack {
                Image(systemName: accessibility.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(accessibility.isTrusted ? .green : .orange)
                Text(accessibility.isTrusted
                     ? "Allowed. Multipaste can paste for you."
                     : "Not allowed. Items are copied, then you press ⌘V yourself.")
                Spacer()
                if !accessibility.isTrusted {
                    Button("Open Settings") {
                        AccessibilityPermission.openSystemSettings()
                    }
                }
            }
            if !accessibility.isTrusted {
                Text("Multipaste already switched on in that list? Remove it with the − button and add it again, or switch it off and on.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Show Welcome Guide Again") {
                onShowOnboarding()
            }
        }
    }

    private var aboutSection: some View {
        Section("Privacy") {
            Text("Multipaste works entirely on this Mac. It contains no networking code: no analytics, no telemetry, no update checks. Your history is stored only in ~/Library/Application Support/Multipaste.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Multipaste \(AppInfo.version) (\(AppInfo.build))")
                Spacer()
                Text("MIT License")
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 12))
        }
    }

    private var uninstallSection: some View {
        Section {
            HStack {
                Text("Deletes all history and settings and moves the app to the Trash.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Uninstall Multipaste…", role: .destructive) {
                    onUninstall()
                }
            }
        }
    }

    // MARK: - Ignored apps

    private func addIgnoredApp() {
        let name = newIgnoredApp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let exists = settings.ignoredApps.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        if !exists {
            settings.ignoredApps.append(name)
        }
        newIgnoredApp = ""
    }

    private func removeIgnoredApp(_ name: String) {
        settings.ignoredApps.removeAll { $0 == name }
    }
}
