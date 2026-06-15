import Foundation
import AppKit

final class IconCache {
    static let shared = IconCache()

    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.dockdiy.iconcache")

    func icon(for path: URL) -> NSImage? {
        let key = path.path(percentEncoded: false)
        if let cached = queue.sync(execute: { cache[key] }) {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: key)
        queue.sync { cache[key] = image }
        return image
    }

    func clear() {
        queue.sync { cache.removeAll() }
    }
}
