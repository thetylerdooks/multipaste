import AppKit
import Combine

/// On-disk format of history.json.
private struct HistoryFile: Codable {
    var version: Int
    var items: [ClipboardItem]
}

/// The clipboard history. Everything lives in
/// ~/Library/Application Support/Multipaste/ (history.json + images/).
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    let directory: URL
    let imagesDirectory: URL

    private let historyURL: URL
    private let settings: AppSettings
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.tylerdooks.multipaste.storage", qos: .utility)
    private let thumbnailCache = NSCache<NSString, NSImage>()

    init(settings: AppSettings) {
        self.settings = settings
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        directory = base.appendingPathComponent("Multipaste", isDirectory: true)
        imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        historyURL = directory.appendingPathComponent("history.json", isDirectory: false)
        thumbnailCache.countLimit = 300

        createDirectories()
        load()
        prune()
        removeOrphanedImages()
    }

    // MARK: - Mutations

    /// Adds a new item on top. If identical content already exists it is moved
    /// to the top instead of being duplicated.
    func insert(_ item: ClipboardItem, imageData: Data? = nil) {
        var updated = items
        if let index = updated.firstIndex(where: { $0.contentHash == item.contentHash }) {
            var existing = updated.remove(at: index)
            existing.date = item.date
            if let name = item.sourceAppName { existing.sourceAppName = name }
            if let bundleID = item.sourceBundleID { existing.sourceBundleID = bundleID }
            updated.insert(existing, at: 0)
        } else {
            var newItem = item
            if let data = imageData {
                let fileName = newItem.id.uuidString + ".png"
                do {
                    try data.write(to: imagesDirectory.appendingPathComponent(fileName), options: .atomic)
                    newItem.imageFile = fileName
                } catch {
                    NSLog("Multipaste: could not store image: %@", error.localizedDescription)
                    return
                }
            }
            updated.insert(newItem, at: 0)
        }
        items = updated
        if !prune() {
            save()
        }
    }

    func moveToTop(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var updated = items
        var item = updated.remove(at: index)
        item.date = Date()
        updated.insert(item, at: 0)
        items = updated
        save()
    }

    /// Deletes every item, including stored images.
    func clearAll() {
        items = []
        thumbnailCache.removeAllObjects()
        if let files = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        save()
    }

    /// Applies the age and count limits. Returns true when something was removed (and saved).
    @discardableResult
    func prune() -> Bool {
        var kept = items
        if settings.maxAgeDays > 0 {
            let cutoff = Date().addingTimeInterval(-Double(settings.maxAgeDays) * 86_400)
            kept.removeAll { $0.date < cutoff }
        }
        let cap = max(1, settings.maxItems)
        if kept.count > cap {
            kept = Array(kept.prefix(cap))
        }
        guard kept.count != items.count else { return false }

        let keptIDs = Set(kept.map { $0.id })
        for removed in items where !keptIDs.contains(removed.id) {
            deleteImage(of: removed)
        }
        items = kept
        save()
        return true
    }

    /// Blocks until pending writes hit the disk (used at quit).
    func flush() {
        ioQueue.sync {}
    }

    // MARK: - Images

    func imageData(for item: ClipboardItem) -> Data? {
        guard let name = item.imageFile else { return nil }
        return try? Data(contentsOf: imagesDirectory.appendingPathComponent(name))
    }

    func thumbnail(for item: ClipboardItem) -> NSImage? {
        guard let name = item.imageFile else { return nil }
        let key = name as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(contentsOf: imagesDirectory.appendingPathComponent(name)) else { return nil }
        let thumbnail = HistoryStore.makeThumbnail(from: image, maxPixels: 160)
        thumbnailCache.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    private static func makeThumbnail(from image: NSImage, maxPixels: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(1, maxPixels / max(size.width, size.height))
        let pixelsWide = max(1, Int((size.width * scale).rounded()))
        let pixelsHigh = max(1, Int((size.height * scale).rounded()))

        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: pixelsWide,
                                         pixelsHigh: pixelsHigh,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return image
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh),
                   from: .zero,
                   operation: .copy,
                   fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let pointSize = NSSize(width: CGFloat(pixelsWide) / 2, height: CGFloat(pixelsHigh) / 2)
        rep.size = pointSize
        let thumbnail = NSImage(size: pointSize)
        thumbnail.addRepresentation(rep)
        return thumbnail
    }

    private func deleteImage(of item: ClipboardItem) {
        guard let name = item.imageFile else { return }
        thumbnailCache.removeObject(forKey: name as NSString)
        try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(name))
    }

    private func removeOrphanedImages() {
        let known = Set(items.compactMap { $0.imageFile })
        guard let files = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where !known.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    // MARK: - Persistence

    private func createDirectories() {
        do {
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            // Only the current user may read the history.
            try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        } catch {
            NSLog("Multipaste: could not create the storage folder: %@", error.localizedDescription)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let file = try decoder.decode(HistoryFile.self, from: data)
            items = file.items
        } catch {
            NSLog("Multipaste: history.json could not be read and will be replaced: %@", error.localizedDescription)
        }
    }

    private func save() {
        let file = HistoryFile(version: 1, items: items)
        let url = historyURL
        ioQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(file)
                try data.write(to: url, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            } catch {
                NSLog("Multipaste: could not save the history: %@", error.localizedDescription)
            }
        }
    }
}
