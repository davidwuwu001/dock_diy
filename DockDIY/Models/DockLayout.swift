import Foundation

struct DockLayout {
    var persistentApps: [DockItem]
    var persistentOthers: [DockItem]
    var recentApps: [DockItem]

    /// All GUIDs currently in use across all sections.
    var allGUIDs: Set<UInt32> {
        let appGUIDs = persistentApps.map(\.guid)
        let otherGUIDs = persistentOthers.map(\.guid)
        let recentGUIDs = recentApps.map(\.guid)
        return Set(appGUIDs + otherGUIDs + recentGUIDs)
    }

    /// Return directory-tile items from the native Dock right side.
    /// DockDIY groups are managed separately and do not use this collection.
    var groups: [DockItem] {
        persistentOthers.filter { $0.tileType == .directory }
    }
}
