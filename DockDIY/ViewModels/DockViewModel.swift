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
    private let dockLauncherService = DockLauncherService.shared

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
        groups = Self.visibleGroups(
            managedGroups: groupManager.scanManagedGroups(),
            layout: layout
        )
    }

    static func visibleGroups(managedGroups: [DockGroup], layout: DockLayout?) -> [DockGroup] {
        managedGroups.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
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
            items.insert(item, at: min(targetIndex, items.count))
            self.layout?.persistentApps = items
        case .others:
            var items = layout.persistentOthers
            guard sourceIndex < items.count else { return }
            let item = items.remove(at: sourceIndex)
            items.insert(item, at: min(targetIndex, items.count))
            self.layout?.persistentOthers = items
        }
        hasUnsavedChanges = true
    }

    func moveItemByOffset(_ itemId: UInt32, in section: DockSection, offset: Int) {
        guard layout != nil, offset != 0 else { return }

        func move(_ items: inout [DockItem]) -> Bool {
            guard let sourceIndex = items.firstIndex(where: { $0.guid == itemId }) else {
                return false
            }
            let targetIndex = max(0, min(sourceIndex + offset, items.count - 1))
            guard targetIndex != sourceIndex else { return false }
            let item = items.remove(at: sourceIndex)
            items.insert(item, at: targetIndex)
            return true
        }

        var didMove = false
        switch section {
        case .apps:
            var items = layout?.persistentApps ?? []
            didMove = move(&items)
            if didMove {
                self.layout?.persistentApps = items
            }
        case .others:
            var items = layout?.persistentOthers ?? []
            didMove = move(&items)
            if didMove {
                self.layout?.persistentOthers = items
            }
        }
        if didMove {
            hasUnsavedChanges = true
        }
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
                     arrangement: StackArrangement = .name,
                     iconSystemName: String = DockGroup.defaultIconSystemName) {
        do {
            let folderURL = try groupManager.createGroupFolder(name: name)

            for app in apps {
                try groupManager.addAppToGroup(groupPath: folderURL, appPath: app.path)
            }
            try groupManager.saveMetadata(
                for: folderURL,
                name: name,
                showAs: showAs,
                arrangement: arrangement,
                iconSystemName: iconSystemName
            )
            loadGroups()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func deleteGroup(_ group: DockGroup) {
        do {
            try groupManager.deleteGroupFolder(at: group.folderPath)
            loadGroups()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func updateGroup(_ group: DockGroup, name: String, apps: [AppInfo],
                     showAs: StackDisplayStyle, arrangement: StackArrangement,
                     iconSystemName: String = DockGroup.defaultIconSystemName) {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return }

            var folderPath = group.folderPath
            if trimmedName != group.name {
                try groupManager.renameGroup(oldName: group.name, newName: trimmedName)
                folderPath = groupManager.groupsDirectory.appendingPathComponent(trimmedName)
            }
            try groupManager.saveMetadata(
                for: folderPath,
                name: trimmedName,
                showAs: showAs,
                arrangement: arrangement,
                iconSystemName: iconSystemName
            )

            let selectedPaths = Set(apps.map(\.path))
            for member in groupManager.scanGroupMembers(groupPath: folderPath) {
                if !selectedPaths.contains(member.appPath) {
                    try groupManager.removeAppFromGroup(
                        groupPath: folderPath,
                        appName: member.symlinkPath.lastPathComponent
                    )
                }
            }

            let existingPaths = Set(
                groupManager.scanGroupMembers(groupPath: folderPath).map(\.appPath)
            )
            for app in apps where !existingPaths.contains(app.path) {
                try groupManager.addAppToGroup(groupPath: folderPath, appPath: app.path)
            }

            updateExistingLauncherIfNeeded(
                group: DockGroup(
                    id: group.id,
                    name: trimmedName,
                    folderPath: folderPath,
                    members: groupManager.scanGroupMembers(groupPath: folderPath),
                    showAs: showAs,
                    arrangement: arrangement,
                    iconSystemName: iconSystemName
                )
            )
            loadGroups()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func updateGroupIcon(_ group: DockGroup, iconSystemName: String) {
        do {
            try groupManager.saveMetadata(
                for: group.folderPath,
                name: group.name,
                showAs: group.showAs,
                arrangement: group.arrangement,
                iconSystemName: iconSystemName
            )

            var updatedGroup = group
            updatedGroup.iconSystemName = iconSystemName
            updateExistingLauncherIfNeeded(group: updatedGroup)
            loadGroups()
        } catch {
            presentError(error, recovery: recoverySuggestion(for: error))
        }
    }

    func revealDockLauncher(for group: DockGroup) {
        do {
            try dockLauncherService.revealLauncher(for: group)
        } catch {
            presentError(error, recovery: "请确认系统允许 DockDIY 在 ~/Applications 中创建应用。")
        }
    }

    func addDockLauncherToLeftDock(for group: DockGroup) {
        do {
            let launcherURL = try dockLauncherService.createLauncher(for: group)
            guard layout != nil else { return }
            if layout?.persistentApps.contains(where: { $0.path == launcherURL }) == true {
                return
            }
            addAppToDock(appPath: launcherURL, to: .apps)
            showApplyConfirmation = true
        } catch {
            presentError(error, recovery: "可以先使用「生成 Dock 图标」在 Finder 中查看生成结果，再手动拖到 Dock 左侧。")
        }
    }

    private func updateExistingLauncherIfNeeded(group: DockGroup) {
        let launcherURL = dockLauncherService.launcherAppURL(for: group)
        guard FileManager.default.fileExists(atPath: launcherURL.path(percentEncoded: false)) else {
            return
        }
        try? dockLauncherService.createLauncher(for: group)
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
