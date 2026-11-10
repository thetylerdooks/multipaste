import SwiftUI

/// Grid used by the Emoji, Kaomoji and Symbols tabs.
struct PickerGridView: View {
    @ObservedObject var model: PopoutViewModel

    var body: some View {
        let groups = model.filteredGroups
        if groups.isEmpty {
            EmptyStateView(symbol: "magnifyingglass",
                           title: "No matches",
                           subtitle: "Try a different word.")
        } else {
            grid(groups)
        }
    }

    private func grid(_ groups: [PickerGroup]) -> some View {
        let columnCount = max(1, model.tab.columns)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount)
        let fontSize = cellFontSize
        let selection = model.selection

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(groups) { group in
                        Text(group.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 6)
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(Array(group.entries.enumerated()), id: \.offset) { pair in
                                PickerCell(entry: pair.element,
                                           fontSize: fontSize,
                                           isSelected: group.start + pair.offset == selection)
                                    .id(group.start + pair.offset)
                                    .onTapGesture {
                                        model.paste(entry: pair.element)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: model.selection) { newValue in
                proxy.scrollTo(newValue)
            }
        }
    }

    private var cellFontSize: CGFloat {
        switch model.tab {
        case .emoji: return 22
        case .kaomoji: return 12
        case .symbols: return 18
        case .clipboard: return 12
        }
    }
}

private struct PickerCell: View {
    let entry: PickerEntry
    let fontSize: CGFloat
    let isSelected: Bool

    @State private var hovering = false

    var body: some View {
        Text(entry.value)
            .font(.system(size: fontSize))
            .foregroundColor(isSelected ? Color.white : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(background)
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .help(entry.keywords)
    }

    private var background: Color {
        if isSelected { return Color.accentColor }
        if hovering { return Color.primary.opacity(0.10) }
        return Color.clear
    }
}
