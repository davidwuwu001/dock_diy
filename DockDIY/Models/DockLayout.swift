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

    /// Return the directory-tile items (groups) from persistentOthers.
    var groups: [DockItem] {
        persistentOthers.filter { $0.tileType == .directory }
    }
}
