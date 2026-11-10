import AppKit

/// One entry in the clipboard history.
struct ClipboardItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case link
        case color
        case code
        case image
        case file
    }

    var id: UUID
    var kind: Kind
    /// Plain text for text / link / colour / code items.
    var text: String?
    /// Optional RTF flavour of the same text.
    var rtf: Data?
    /// File name inside the images/ folder for image items.
    var imageFile: String?
    var imageWidth: Int?
    var imageHeight: Int?
    /// Absolute paths for file items.
    var filePaths: [String]?
    var sourceAppName: String?
    var sourceBundleID: String?
    var date: Date
    /// Stable fingerprint of the content, used for de-duplication.
    var contentHash: String

    init(kind: Kind,
         text: String? = nil,
         rtf: Data? = nil,
         imageWidth: Int? = nil,
         imageHeight: Int? = nil,
         filePaths: [String]? = nil,
         sourceAppName: String? = nil,
         sourceBundleID: String? = nil,
         date: Date = Date(),
         contentHash: String) {
        self.id = UUID()
        self.kind = kind
        self.text = text
        self.rtf = rtf
        self.imageFile = nil
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.filePaths = filePaths
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.date = date
        self.contentHash = contentHash
    }
}

extension ClipboardItem {
    var fileNames: [String] {
        (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
    }

    /// Host of a link item, derived from the URL string only (never fetched).
    var host: String? {
        guard kind == .link, let text = text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed)?.host
    }

    /// Short text shown in the history list.
    var previewText: String {
        switch kind {
        case .image:
            if let width = imageWidth, let height = imageHeight {
                return "Image  \(width) × \(height)"
            }
            return "Image"
        case .file:
            let names = fileNames
            guard let first = names.first else { return "File" }
            if names.count > 1 {
                return "\(first) and \(names.count - 1) more"
            }
            return first
        case .code:
            let head = String((text ?? "").prefix(600))
            let lines = head.split(whereSeparator: { $0.isNewline }).prefix(3)
            return lines.map { String($0) }.joined(separator: "\n")
        case .text, .link, .color:
            let head = String((text ?? "").prefix(300))
            let parts = head.split(whereSeparator: { $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return parts.joined(separator: " ")
        }
    }

    /// Everything the search field matches against.
    var searchableText: String {
        var parts: [String] = []
        if let text = text { parts.append(String(text.prefix(4000))) }
        parts.append(contentsOf: fileNames)
        if let app = sourceAppName { parts.append(app) }
        switch kind {
        case .text: parts.append("text")
        case .link: parts.append("link url")
        case .color: parts.append("color colour")
        case .code: parts.append("code")
        case .image: parts.append("image screenshot picture")
        case .file: parts.append("file")
        }
        return parts.joined(separator: " ")
    }

    var sourceLabel: String {
        if let name = sourceAppName, !name.isEmpty { return name }
        return "Unknown app"
    }
}

/// Decides what kind of text was copied.
enum ContentClassifier {
    static func classify(_ text: String) -> ClipboardItem.Kind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if ColorParser.parse(trimmed) != nil { return .color }
        if isLink(trimmed) { return .link }
        if looksLikeCode(text) { return .code }
        return .text
    }

    static func isLink(_ candidate: String) -> Bool {
        let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 2048 else { return false }
        if value.contains(where: { $0.isWhitespace || $0.isNewline }) { return false }
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" || scheme == "ftp" else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        return true
    }

    static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: { $0.isNewline }).map { String($0) }
        guard lines.count >= 2 else { return false }

        var score = 0
        if text.contains("{") && text.contains("}") { score += 2 }

        let semicolonLines = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).hasSuffix(";")
        }.count
        if semicolonLines >= 2 {
            score += 2
        } else if semicolonLines == 1 {
            score += 1
        }

        let indentedLines = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }.count
        if indentedLines >= 2 { score += 1 }

        let markers = [
            "func ", "function ", "def ", "class ", "import ", "#include", "return ",
            "const ", "let ", "var ", "public ", "private ", "static ", "=>", "->",
            "if (", "for (", "while (", "</", "SELECT ", "println", "console.log"
        ]
        if markers.contains(where: { text.contains($0) }) { score += 1 }

        return score >= 2
    }
}

/// Parses #RGB, #RRGGBB, #RRGGBBAA, rgb() and rgba() strings.
enum ColorParser {
    static func parse(_ raw: String) -> NSColor? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 4, value.count <= 48 else { return nil }
        if value.hasPrefix("#") {
            return parseHex(String(value.dropFirst()))
        }
        let lower = value.lowercased()
        if (lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(")) && lower.hasSuffix(")") {
            return parseRGB(lower)
        }
        return nil
    }

    private static func parseHex(_ hex: String) -> NSColor? {
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        guard hex.allSatisfy({ $0.isHexDigit }) else { return nil }

        var full = hex
        if hex.count == 3 {
            full = hex.map { "\($0)\($0)" }.joined()
        }
        guard let number = UInt64(full, radix: 16) else { return nil }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        if full.count == 8 {
            red = CGFloat((number >> 24) & 0xFF) / 255
            green = CGFloat((number >> 16) & 0xFF) / 255
            blue = CGFloat((number >> 8) & 0xFF) / 255
            alpha = CGFloat(number & 0xFF) / 255
        } else {
            red = CGFloat((number >> 16) & 0xFF) / 255
            green = CGFloat((number >> 8) & 0xFF) / 255
            blue = CGFloat(number & 0xFF) / 255
            alpha = 1
        }
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func parseRGB(_ value: String) -> NSColor? {
        guard let open = value.firstIndex(of: "("),
              let close = value.lastIndex(of: ")"),
              open < close else { return nil }
        let inner = value[value.index(after: open)..<close]
        let parts = inner
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
            .map { String($0) }
        guard parts.count == 3 || parts.count == 4 else { return nil }

        var components: [CGFloat] = []
        for part in parts.prefix(3) {
            guard let component = channel(part) else { return nil }
            components.append(component)
        }

        var alpha: CGFloat = 1
        if parts.count == 4 {
            let part = parts[3]
            if part.hasSuffix("%"), let percent = Double(String(part.dropLast())) {
                alpha = CGFloat(percent / 100)
            } else if let number = Double(part) {
                alpha = CGFloat(number)
            } else {
                return nil
            }
            alpha = min(max(alpha, 0), 1)
        }
        return NSColor(srgbRed: components[0], green: components[1], blue: components[2], alpha: alpha)
    }

    private static func channel(_ part: String) -> CGFloat? {
        if part.hasSuffix("%") {
            guard let percent = Double(String(part.dropLast())) else { return nil }
            return CGFloat(min(max(percent, 0), 100) / 100)
        }
        guard let number = Double(part) else { return nil }
        return CGFloat(min(max(number, 0), 255) / 255)
    }
}

enum RelativeTime {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func string(from date: Date, now: Date = Date()) -> String {
        let seconds = Int(max(0, now.timeIntervalSince(date)))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        return dateFormatter.string(from: date)
    }
}
