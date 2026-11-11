import AppKit
import Combine
import SwiftUI

/// First-run welcome window: what Multipaste does and why it asks for Accessibility.
struct OnboardingView: View {
    static let windowSize = NSSize(width: 500, height: 710)

    @ObservedObject var settings: AppSettings
    @ObservedObject var accessibility: AccessibilityMonitor
    var onDone: () -> Void

    private var accessibilityTrusted: Bool { accessibility.isTrusted }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            step(symbol: "keyboard",
                 title: "Press \(settings.hotKeyDisplay) anywhere",
                 text: "Your clipboard history opens right at the mouse pointer. Pick an item with the arrow keys and Return, or press ⌘1 to ⌘9. You can change the shortcut in Settings.")
            step(symbol: "hand.raised",
                 title: "Why Accessibility access?",
                 text: "Only to press ⌘V for you in the app you were using, so the item you picked is pasted straight away. Multipaste never reads your screen or your keystrokes. Without this permission it still copies the item and you press ⌘V yourself.")
            permissionBox
            step(symbol: "lock.shield",
                 title: "Private by design",
                 text: "Everything stays on this Mac. Multipaste has no networking code at all, and it skips passwords from password managers.")
            step(symbol: "power",
                 title: "Starts with your Mac",
                 text: "Multipaste starts automatically when you log in. You can turn this off in Settings.")
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Get Started") {
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: OnboardingView.windowSize.width, height: OnboardingView.windowSize.height)
        .onAppear {
            accessibility.start()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 34))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to Multipaste")
                    .font(.system(size: 22, weight: .bold))
                Text(AppInfo.tagline)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func step(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var permissionBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(accessibilityTrusted ? .green : .orange)
                Text(accessibilityTrusted ? "Accessibility access is allowed." : "Accessibility access is not allowed yet.")
                    .font(.system(size: 12, weight: .medium))
            }
            HStack(spacing: 8) {
                Button("Allow Accessibility…") {
                    AccessibilityPermission.requestWithPrompt()
                }
                .disabled(accessibilityTrusted)
                Button("Open Accessibility Settings") {
                    AccessibilityPermission.openSystemSettings()
                }
            }
            if !accessibilityTrusted {
                Text("Multipaste already switched on in the list? Remove it with the − button and add it again, or switch it off and on.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .padding(.leading, 38)
    }
}
