import AppKit
import SwiftUI

/// Root view of the popout: search, tabs, content and footer.
struct PopoutView: View {
    @ObservedObject var model: PopoutViewModel
    @ObservedObject var store: HistoryStore

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            tabBar
            Divider().opacity(0.6)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !model.accessibilityTrusted {
                accessibilityBanner
            }
            Divider().opacity(0.6)
            footer
        }
        .frame(width: PopoutController.panelSize.width, height: PopoutController.panelSize.height)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            SearchField(text: $model.query, placeholder: "Search clipboard", focusToken: model.focusToken)
                .frame(height: 22)
            if !model.query.isEmpty {
                Button(action: { model.query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(PopoutTab.allCases) { tab in
                TabButton(title: tab.title, isSelected: model.tab == tab) {
                    model.tab = tab
                    model.focusToken += 1
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.tab == .clipboard {
            ClipboardListView(model: model, store: store)
        } else {
            PickerGridView(model: model)
                .id(model.tab)
        }
    }

    private var accessibilityBanner: some View {
        Button(action: { model.onRequestAccessibility?() }) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Auto-paste is off. Click to allow Accessibility.")
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            FooterButton(key: "↩", label: "Paste") {
                model.activateSelection()
            }
            FooterButton(key: "⇥", label: "Next tab") {
                model.cycleTab(forward: true)
            }
            FooterButton(key: "esc", label: "Close") {
                model.onClose?()
            }
            Spacer(minLength: 0)
            Button(action: { model.onOpenSettings?() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

// MARK: - Small controls

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(backgroundColor)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var backgroundColor: Color {
        if isSelected { return Color.accentColor }
        if hovering { return Color.primary.opacity(0.08) }
        return Color.clear
    }
}

private struct FooterButton: View {
    let key: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(key)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.10))
                    )
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
