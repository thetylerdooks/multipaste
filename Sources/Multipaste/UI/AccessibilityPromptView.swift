import AppKit
import SwiftUI

/// Small window shown whenever Multipaste starts (or tries to paste) without
/// Accessibility access. It closes itself once access is granted.
struct AccessibilityPromptView: View {
    static let windowSize = NSSize(width: 440, height: 380)

    @ObservedObject var monitor: AccessibilityMonitor
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
                Text("Let Multipaste paste for you")
                    .font(.system(size: 18, weight: .bold))
            }
            Text("Multipaste needs Accessibility access for one thing only: pressing ⌘V in the app you were using, so the item you pick is pasted straight away. It never reads your screen or your keystrokes, and everything stays on this Mac.")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Text("Open Accessibility Settings and switch on Multipaste. This window closes by itself once access is allowed.")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Text("Multipaste already switched on in the list? That entry belongs to an older copy of the app. Select it, remove it with the − button, then add Multipaste again with + (or switch it off and on again).")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: monitor.isTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(monitor.isTrusted ? .green : .orange)
                Text(monitor.isTrusted ? "Accessibility access is allowed." : "Waiting for Accessibility access…")
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer(minLength: 0)
            HStack {
                Button("Not Now") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open Accessibility Settings") {
                    AccessibilityPermission.openSystemSettings()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: AccessibilityPromptView.windowSize.width, height: AccessibilityPromptView.windowSize.height)
    }
}
