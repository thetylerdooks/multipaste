import AppKit
import SwiftUI

/// The "Recent" list on the Clipboard tab, newest first.
struct ClipboardListView: View {
    @ObservedObject var model: PopoutViewModel
    @ObservedObject var store: HistoryStore

    var body: some View {
        let items = model.filteredItems
        if items.isEmpty {
            emptyState
        } else {
            list(items)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.items.isEmpty {
            EmptyStateView(symbol: "doc.on.clipboard",
                           title: "Nothing copied yet",
                           subtitle: "Copy something with ⌘C and it will show up here.")
        } else {
            EmptyStateView(symbol: "magnifyingglass",
                           title: "No matches",
                           subtitle: "Nothing in your history matches that search.")
        }
    }

    private func list(_ items: [ClipboardItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Text("Recent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                    ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                        ClipboardRowView(item: pair.element,
                                         index: pair.offset,
                                         isSelected: pair.offset == model.selection,
                                         store: store)
                            .id(pair.element.id)
                            .onTapGesture {
                                model.paste(item: pair.element)
                            }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .onChange(of: model.selection) { newValue in
                let current = model.filteredItems
                if newValue >= 0 && newValue < current.count {
                    proxy.scrollTo(current[newValue].id)
                }
            }
        }
    }
}

/// One history row: preview, content, source app, time and the ⌘1–9 badge.
struct ClipboardRowView: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let store: HistoryStore

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ItemPreviewIcon(item: item, store: store)
            VStack(alignment: .leading, spacing: 3) {
                title
                metadata
            }
            Spacer(minLength: 4)
            if index < 9 {
                badge
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor }
        if hovering { return Color.primary.opacity(0.08) }
        return Color.clear
    }

    private var primaryColor: Color {
        isSelected ? Color.white : Color.primary
    }

    private var secondaryColor: Color {
        isSelected ? Color.white.opacity(0.8) : Color.secondary
    }

    @ViewBuilder
    private var title: some View {
        switch item.kind {
        case .code:
            Text(item.previewText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(primaryColor)
                .lineLimit(3)
        case .link:
            VStack(alignment: .leading, spacing: 1) {
                Text(item.host ?? "Link")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primaryColor)
                    .lineLimit(1)
                Text(item.previewText)
                    .font(.system(size: 10))
                    .foregroundColor(secondaryColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .color:
            Text(item.previewText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(primaryColor)
                .lineLimit(1)
        case .text, .image, .file:
            Text(item.previewText)
                .font(.system(size: 12))
                .foregroundColor(primaryColor)
                .lineLimit(2)
        }
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            if let icon = AppIconCache.shared.icon(forBundleID: item.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 12, height: 12)
            }
            Text(item.sourceLabel)
                .lineLimit(1)
            Text("·")
            Text(RelativeTime.string(from: item.date))
                .lineLimit(1)
        }
        .font(.system(size: 10))
        .foregroundColor(secondaryColor)
    }

    private var badge: some View {
        Text("⌘\(index + 1)")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(secondaryColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.08))
            )
    }
}

/// Leading 34pt preview: thumbnail, colour swatch, file icon or a type symbol.
struct ItemPreviewIcon: View {
    let item: ClipboardItem
    let store: HistoryStore

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.07))
            preview
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let thumbnail = store.thumbnail(for: item) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 34)
            } else {
                symbol("photo")
            }
        case .color:
            if let color = ColorParser.parse(item.text ?? "") {
                Color(nsColor: color)
            } else {
                symbol("paintpalette")
            }
        case .file:
            if let path = item.filePaths?.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 26, height: 26)
            } else {
                symbol("doc")
            }
        case .link:
            symbol("link")
        case .code:
            symbol("chevron.left.forwardslash.chevron.right")
        case .text:
            symbol("text.alignleft")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
    }
}

/// Caches app icons looked up from the bundle identifier of the source app.
final class AppIconCache {
    static let shared = AppIconCache()

    private var icons: [String: NSImage] = [:]
    private var missing = Set<String>()

    private init() {}

    func icon(forBundleID bundleID: String?) -> NSImage? {
        guard let identifier = bundleID, !identifier.isEmpty else { return nil }
        if let cached = icons[identifier] { return cached }
        if missing.contains(identifier) { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            missing.insert(identifier)
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[identifier] = icon
        return icon
    }
}
