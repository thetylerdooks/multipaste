import AppKit
import Combine

enum PopoutTab: Int, CaseIterable, Identifiable {
    case clipboard
    case emoji
    case kaomoji
    case symbols

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .emoji: return "Emoji"
        case .kaomoji: return "Kaomoji"
        case .symbols: return "Symbols"
        }
    }

    /// Number of grid columns (1 for the clipboard list).
    var columns: Int {
        switch self {
        case .clipboard: return 1
        case .emoji: return 8
        case .kaomoji: return 2
        case .symbols: return 8
        }
    }

    var isGrid: Bool { self != .clipboard }
}

/// State of the popout: search text, active tab and keyboard selection.
final class PopoutViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            if query != oldValue { selection = 0 }
        }
    }

    @Published var tab: PopoutTab = .clipboard {
        didSet {
            if tab != oldValue { selection = 0 }
        }
    }

    /// Index of the highlighted row / cell among the currently visible entries.
    @Published var selection: Int = 0

    /// Bumped every time the search field should take keyboard focus.
    @Published var focusToken: Int = 0

    @Published var accessibilityTrusted: Bool = true

    let store: HistoryStore

    var onPasteItem: ((ClipboardItem) -> Void)?
    var onPasteText: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRequestAccessibility: (() -> Void)?

    init(store: HistoryStore) {
        self.store = store
        // Follows the shared monitor, so the banner disappears the moment access is granted.
        AccessibilityMonitor.shared.$isTrusted.assign(to: &$accessibilityTrusted)
    }

    // MARK: - Visible content

    var filteredItems: [ClipboardItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return store.items }
        return store.items.filter {
            $0.searchableText.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var filteredGroups: [PickerGroup] {
        let source: [PickerGroup]
        switch tab {
        case .clipboard: return []
        case .emoji: source = EmojiData.groups
        case .kaomoji: source = KaomojiData.groups
        case .symbols: source = SymbolData.groups
        }
        return PickerData.filter(source, query: query)
    }

    // MARK: - Actions

    func prepareForOpen() {
        query = ""
        tab = .clipboard
        selection = 0
        AccessibilityMonitor.shared.start()
        focusToken += 1
    }

    func cycleTab(forward: Bool) {
        let all = PopoutTab.allCases
        guard let index = all.firstIndex(of: tab) else { return }
        let next = (index + (forward ? 1 : all.count - 1)) % all.count
        tab = all[next]
    }

    func moveSelection(dx: Int, dy: Int) {
        if tab == .clipboard {
            let count = filteredItems.count
            guard count > 0 else { return }
            selection = min(max(selection + dy, 0), count - 1)
        } else {
            moveInGrid(dx: dx, dy: dy)
        }
    }

    /// Pastes whatever is currently highlighted.
    func activateSelection() {
        if tab == .clipboard {
            let items = filteredItems
            guard !items.isEmpty else { return }
            let index = min(max(selection, 0), items.count - 1)
            onPasteItem?(items[index])
        } else {
            let entries = filteredGroups.flatMap { $0.entries }
            guard !entries.isEmpty else { return }
            let index = min(max(selection, 0), entries.count - 1)
            onPasteText?(entries[index].value)
        }
    }

    /// Cmd+1 … Cmd+9: pastes the n-th visible clipboard item (0-based).
    func quickPaste(_ index: Int) {
        guard tab == .clipboard else { return }
        let items = filteredItems
        guard index >= 0, index < items.count else { return }
        onPasteItem?(items[index])
    }

    func paste(item: ClipboardItem) {
        onPasteItem?(item)
    }

    func paste(entry: PickerEntry) {
        onPasteText?(entry.value)
    }

    // MARK: - Grid navigation

    private func moveInGrid(dx: Int, dy: Int) {
        let groups = filteredGroups
        let total = groups.reduce(0) { $0 + $1.entries.count }
        guard total > 0 else { return }

        var index = min(max(selection, 0), total - 1)
        if dx != 0 {
            index = min(max(index + dx, 0), total - 1)
        }

        if dy != 0, let groupIndex = groups.firstIndex(where: { index >= $0.start && index < $0.start + $0.entries.count }) {
            let columns = max(1, tab.columns)
            let group = groups[groupIndex]
            let count = group.entries.count
            let offset = index - group.start
            let column = offset % columns
            let row = offset / columns
            let lastRow = (count - 1) / columns

            if dy > 0 {
                if row < lastRow {
                    index = min(group.start + (row + 1) * columns + column, group.start + count - 1)
                } else if groupIndex + 1 < groups.count {
                    let next = groups[groupIndex + 1]
                    index = next.start + min(column, next.entries.count - 1)
                }
            } else {
                if row > 0 {
                    index = group.start + (row - 1) * columns + column
                } else if groupIndex > 0 {
                    let previous = groups[groupIndex - 1]
                    let previousCount = previous.entries.count
                    let previousLastRow = (previousCount - 1) / columns
                    index = previous.start + min(previousLastRow * columns + column, previousCount - 1)
                }
            }
        }
        selection = index
    }
}
