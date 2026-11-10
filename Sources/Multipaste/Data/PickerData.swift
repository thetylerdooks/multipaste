import Foundation

/// One pasteable entry in the Emoji / Kaomoji / Symbols tabs.
struct PickerEntry {
    let value: String
    /// Lower-case search keywords.
    let keywords: String
}

struct PickerGroup: Identifiable {
    let id: Int
    let title: String
    let entries: [PickerEntry]
    /// Index of the first entry when all visible groups are flattened.
    var start: Int
}

enum PickerData {
    /// Parses a block with one entry per line: the value, a space, then keywords.
    static func parse(_ block: String) -> [PickerEntry] {
        var result: [PickerEntry] = []
        for line in block.split(whereSeparator: { $0.isNewline }) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if let space = trimmed.firstIndex(of: " ") {
                let value = String(trimmed[..<space])
                let keywords = String(trimmed[trimmed.index(after: space)...])
                result.append(PickerEntry(value: value, keywords: keywords.lowercased()))
            } else {
                result.append(PickerEntry(value: trimmed, keywords: ""))
            }
        }
        return result
    }

    static func makeGroups(_ sections: [(title: String, entries: [PickerEntry])]) -> [PickerGroup] {
        var groups: [PickerGroup] = []
        var start = 0
        for (index, section) in sections.enumerated() {
            groups.append(PickerGroup(id: index, title: section.title, entries: section.entries, start: start))
            start += section.entries.count
        }
        return groups
    }

    /// Keeps only entries matching the query and recomputes the flattened start indices.
    static func filter(_ groups: [PickerGroup], query: String) -> [PickerGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result: [PickerGroup] = []
        var start = 0
        for group in groups {
            let entries: [PickerEntry]
            if needle.isEmpty || group.title.lowercased().contains(needle) {
                entries = group.entries
            } else {
                entries = group.entries.filter {
                    $0.keywords.contains(needle) || $0.value.contains(needle)
                }
            }
            if entries.isEmpty { continue }
            result.append(PickerGroup(id: group.id, title: group.title, entries: entries, start: start))
            start += entries.count
        }
        return result
    }
}
