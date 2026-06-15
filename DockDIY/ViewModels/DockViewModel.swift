import Foundation
import SwiftUI
import Observation

@Observable
final class DockViewModel {

    var layout: DockLayout?
    var groups: [DockGroup] = []
    var isLoading = false
    var hasUnsavedChanges = false
    var errorMessage: String?
    var errorRecovery: String?
    var showError = false
    var showApplyConfirmation = false
    var selectedGroupId: UUID?
    var plistWritable = false

    // Sheet states
    var showGroupEditor = false
    var editingGroup: DockGroup?
    var showAppPicker = false
    var appPickerTargetGroupId: UUID?
    var showDockAppPicker = false
    var dockAppPickerTargetSection: DockSection?
    var showDockItemEditor = false
    var editingDockItem: DockItem?
    var editingDockSection: DockSection?

    private let plistService = DockPlistService.shared
    private let groupManager = GroupManager.shared

    // MARK: - Load

    func loadDockLayout() {
        isLoading = true
        errorMessage = nil
        errorRecovery = nil
        do {
            let newLayout = try plistService.loadLayout()
            layout = newLayout
            loadGroups()
            hasUnsavedChanges = false
            checkPlistWritable()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
        isLoading = false
    }

    private func checkPlistWritable() {
        let url = plistService.plistURL
        plistWritable = FileManager.default.isWritableFile(atPath: url.path(percentEncoded: false))
    }

    private func loadGroups() {
        guard let layout else { return }
        groups = layout.persistentOthers
            .filter { $0.tileType == .directory }
            .compactMap { item -> DockGroup? in
                let members = groupManager.scanGroupMembers(groupPath: item.path)
                let tileData = item.rawPlistData["tile-data"] as? [String: Any] ?? [:]
                let showAsRaw = tileData["showas"] as? Int ?? 0
                let arrangementRaw = tileData["arrangement"] as? Int ?? 1

                return DockGroup(
                    name: item.label,
                    folderPath: item.path,
                    members: members,
                    showAs: StackDisplayStyle(rawValue: showAsRaw) ?? .auto,
                    arrangement: StackArrangement(rawValue: arrangementRaw) ?? .name
                )
            }
    }

    // MARK: - Move Items

    func moveItem(in section: DockSection, from sourceIndex: Int, to targetIndex: Int) {
        guard let layout else { return }
        switch section {
        case .apps:
            var items = layout.persistentApps
            guard sourceIndex < items.count else { return }
            let item = items.remove(at: sourceIndex)
            let adjustedTarget = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
            items.insert(item, at: min(adjustedTarget, items.count))
            self.layout?.persistentApps = items
        case .others:
            var items = layout.persistentOthers
            guard sourceIndex < items.count else { return }
            let item = items.remove(at: sourceIndex)
            let adjustedTarget = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
            items.insert(item, at: min(adjustedTarget, items.count))
            self.layout?.persistentOthers = items
        }
        hasUnsavedChanges = true
    }

    func moveItemAcrossSections(itemId: UInt32, from source: DockSection, to target: DockSection) {
        guard let layout else { return }
        let sourceItems = source == .apps ? layout.persistentApps : layout.persistentOthers
        guard let item = sourceItems.first(where: { $0.guid == itemId }) else { return }

        removeItem(itemId, from: source)
        switch target {
        case .apps:
            self.layout?.persistentApps.append(item)
        case .others:
            self.layout?.persistentOthers.append(item)
        }
        hasUnsavedChanges = true
    }

    // MARK: - Add / Remove Items

    func addAppToDock(appPath: URL, to section: DockSection, at index: Int? = nil) {
        guard let layout else { return }
        let existingGUIDs = layout.allGUIDs
        let guid = DockItem.generateGUID(excluding: existingGUIDs)
        let bundle = Bundle(url: appPath)
        let label = (bundle?.infoDictionary?["CFBundleName"] as? String)
            ?? appPath.deletingPathExtension().lastPathComponent

        var tileDataDict: [String: Any] = [
            "file-data": [
                "_CFURLString": appPath.absoluteString,
                "_CFURLStringType": 15
            ] as [String: Any],
            "file-label": label,
            "file-type": 41
        ]
        if let bid = bundle?.bundleIdentifier {
            tileDataDict["bundle-identifier"] = bid
        }

        let rawDict: [String: Any] = [
            "GUID": guid,
            "tile-type": "file-tile",
            "tile-data": tileDataDict
        ]

        var item = DockItem(
            guid: guid,
            tileType: .file,
            label: label,
            path: appPath,
            bundleIdentifier: bundle?.bundleIdentifier,
            rawPlistData: rawDict
        )
        item.loadIcon()

        switch section {
        case .apps:
            var items = layout.persistentApps
            if let idx = index {
                items.insert(item, at: min(idx, items.count))
            } else {
                items.append(item)
            }
            self.layout?.persistentApps = items
        case .others:
            var items = layout.persistentOthers
            if let idx = index {
                items.insert(item, at: min(idx, items.count))
            } else {
                items.append(item)
            }
            self.layout?.persistentOthers = items
        }
        hasUnsavedChanges = true
    }

    func removeItem(_ itemId: UInt32, from section: DockSection) {
        guard layout != nil else { return }
        switch section {
        case .apps:
            self.layout?.persistentApps.removeAll { $0.guid == itemId }
        case .others:
            self.layout?.persistentOthers.removeAll { $0.guid == itemId }
        }
        hasUnsavedChanges = true
    }

    func updateItem(_ itemId: UInt32, in section: DockSection,
                    label: String, path: URL, bundleIdentifier: String?) {
        guard layout != nil else { return }

        func updated(_ item: DockItem) -> DockItem {
            var next = item
            next.label = label
            next.path = path
            next.bundleIdentifier = bundleIdentifier
            next.loadIcon()
            return next
        }

        switch section {
        case .apps:
            self.layout?.persistentApps = self.layout?.persistentApps.map {
                $0.guid == itemId ? updated($0) : $0
            } ?? []
        case .others:
            self.layout?.persistentOthers = self.layout?.persistentOthers.map {
                $0.guid == itemId ? updated($0) : $0
            } ?? []
        }
        hasUnsavedChanges = true
    }

    // MARK: - Group Management

    func createGroup(name: String, apps: [AppInfo],
                     showAs: StackDisplayStyle = .auto,
                     arrangement: StackArrangement = .name) {
        do {
            let folderURL = try groupManager.createGroupFolder(name: name)

            for app in apps {
                try groupManager.addAppToGroup(groupPath: folderURL, appPath: app.path)
            }

            guard let layout else { return }
            let guid = DockItem.generateGUID(excluding: layout.allGUIDs)

            let rawDict: [String: Any] = [
                "GUID": guid,
                "tile-type": "directory-tile",
                "tile-data": [
                    "file-data": [
                        "_CFURLString": "file://\(folderURL.path(percentEncoded: false))",
                        "_CFURLStringType": 15
                    ] as [String: Any],
                    "file-label": name,
                    "file-type": 2,
                    "arrangement": arrangement.rawValue,
                    "displayas": 0,
                    "showas": showAs.rawValue
                ] as [String: Any]
            ]

            var item = DockItem(
                guid: guid,
                tileType: .directory,
                label: name,
                path: folderURL,
                rawPlistData: rawDict
            )
            item.loadIcon()

            var others = layout.persistentOthers
            others.append(item)
            self.layout?.persistentOthers = others
            hasUnsavedChanges = true
            loadGroups()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func deleteGroup(_ group: DockGroup) {
        do {
            try groupManager.deleteGroupFolder(at: group.folderPath)
            self.layout?.persistentOthers.removeAll {
                $0.tileType == .directory && $0.label == group.name
            }
            hasUnsavedChanges = true
            loadGroups()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func updateGroup(_ group: DockGroup, name: String,
                     showAs: StackDisplayStyle, arrangement: StackArrangement) {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return }

            var folderPath = group.folderPath
            if trimmedName != group.name {
                try groupManager.renameGroup(oldName: group.name, newName: trimmedName)
                folderPath = groupManager.groupsDirectory.appendingPathComponent(trimmedName)
            }

            self.layout?.persistentOthers = self.layout?.persistentOthers.map { item in
                guard item.tileType == .directory && item.path == group.folderPath else {
                    return item
                }

                var next = item
                next.label = trimmedName
                next.path = folderPath
                if var tileData = next.rawPlistData["tile-data"] as? [String: Any] {
                    tileData["file-label"] = trimmedName
                    tileData["arrangement"] = arrangement.rawValue
                    tileData["showas"] = showAs.rawValue
                    var fileData = tileData["file-data"] as? [String: Any] ?? [:]
                    fileData["_CFURLString"] = "file://\(folderPath.path(percentEncoded: false))"
                    fileData["_CFURLStringType"] = 15
                    tileData["file-data"] = fileData
                    next.rawPlistData["tile-data"] = tileData
                }
                next.loadIcon()
                return next
            } ?? []

            hasUnsavedChanges = true
            loadGroups()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func addAppToGroup(groupId: UUID, app: AppInfo) {
        guard let group = groups.first(where: { $0.id == groupId }) else { return }
        do {
            try groupManager.addAppToGroup(groupPath: group.folderPath, appPath: app.path)
            loadGroups()
            hasUnsavedChanges = true
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func removeAppFromGroup(groupId: UUID, appName: String) {
        guard let group = groups.first(where: { $0.id == groupId }) else { return }
        do {
            try groupManager.removeAppFromGroup(groupPath: group.folderPath, appName: appName)
            loadGroups()
            hasUnsavedChanges = true
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    // MARK: - Apply Changes

    func applyChanges() {
        guard let layout else { return }
        do {
            try plistService.saveLayout(layout)
            try plistService.reloadDock()
            hasUnsavedChanges = false
            // Reload after Dock restarts
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.loadDockLayout()
            }
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    // MARK: - Error Handling

    func presentError(_ error: Error, recovery: String? = nil) {
        errorMessage = error.localizedDescription
        errorRecovery = recovery
        showError = true
    }

    private func recoverySuggestion(for error: Error) -> String? {
        if let plistError = error as? DockPlistError {
            switch plistError {
            case .plistNotFound:
                return "请确认 macOS 系统正常运行。可以尝试重启电脑后再打开此应用。"
            case .invalidFormat:
                return "Dock 配置文件可能已损坏。可以在「终端」中运行 `defaults delete com.apple.dock && killall Dock` 重置 Dock。"
            case .writeFailed:
                return "请检查是否对 ~/Library/Preferences/com.apple.dock.plist 有写入权限。"
            case .killallFailed:
                return "Dock 进程可能未运行。请稍后手动重启 Dock 或重启电脑。"
            }
        }
        if let nsError = error as NSError? {
            if nsError.domain == NSCocoaErrorDomain, nsError.code == 513 {
                return "权限不足。请在「系统设置 > 隐私与安全性 > 完全磁盘访问权限」中授权 DockDIY。"
            }
        }
        return nil
    }
}

// MARK: - DockSection

enum DockSection: String, Codable {
    case apps
    case others
}
