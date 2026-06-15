import Foundation
import AppKit

// MARK: - TileType

enum TileType: String, Codable {
    case file = "file-tile"
    case directory = "directory-tile"
    case spacer = "spacer-tile"
    case url = "url-tile"
}

// MARK: - DockItem

struct DockItem: Identifiable {
    var guid: UInt32
    var tileType: TileType
    var label: String
    var path: URL
    var bundleIdentifier: String?
    var icon: NSImage?
    var rawPlistData: [String: Any]

    var id: UInt32 { guid }

    init(guid: UInt32, tileType: TileType, label: String, path: URL,
         bundleIdentifier: String? = nil, icon: NSImage? = nil,
         rawPlistData: [String: Any] = [:]) {
        self.guid = guid
        self.tileType = tileType
        self.label = label
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.rawPlistData = rawPlistData
    }

    /// Load icon from the app bundle or file system (cached).
    mutating func loadIcon() {
        icon = IconCache.shared.icon(for: path)
    }

    /// Generate a new random GUID that doesn't conflict with existing ones.
    static func generateGUID(excluding existing: Set<UInt32> = []) -> UInt32 {
        var newGUID: UInt32
        repeat {
            newGUID = UInt32.random(in: 1...UInt32.max)
        } while existing.contains(newGUID)
        return newGUID
    }
}

// MARK: - Equatable / Hashable

extension DockItem: Equatable {
    static func == (lhs: DockItem, rhs: DockItem) -> Bool {
        lhs.guid == rhs.guid
    }
}

extension DockItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(guid)
    }
}
