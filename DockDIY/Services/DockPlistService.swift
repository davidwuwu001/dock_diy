import Foundation
import AppKit

enum DockPlistError: LocalizedError {
    case plistNotFound
    case invalidFormat
    case writeFailed(Error)
    case killallFailed(Error)

    var errorDescription: String? {
        switch self {
        case .plistNotFound:
            return "找不到 Dock 配置文件"
        case .invalidFormat:
            return "Dock 配置文件格式无效"
        case .writeFailed(let error):
            return "写入 Dock 配置失败: \(error.localizedDescription)"
        case .killallFailed(let error):
            return "刷新 Dock 失败: \(error.localizedDescription)"
        }
    }
}

final class DockPlistService {

    static let shared = DockPlistService()

    private let fileManager = FileManager.default
    private let backupDir: URL
    private let maxBackups = 5

    private(set) var rawPlistDict: [String: Any] = [:]

    var plistURL: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Preferences/com.apple.dock.plist")
    }

    init() {
        let appSupport = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DockDIY")
        backupDir = appSupport.appendingPathComponent("backups")
        try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
    }

    // MARK: - Read

    func loadLayout() throws -> DockLayout {
        guard fileManager.fileExists(atPath: plistURL.path(percentEncoded: false)) else {
            throw DockPlistError.plistNotFound
        }

        let data = try Data(contentsOf: plistURL)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            throw DockPlistError.invalidFormat
        }

        rawPlistDict = dict

        let persistentApps = parseItems(dict["persistent-apps"] as? [[String: Any]] ?? [])
        let persistentOthers = parseItems(dict["persistent-others"] as? [[String: Any]] ?? [])
        let recentApps = parseItems(dict["recent-apps"] as? [[String: Any]] ?? [])

        return DockLayout(
            persistentApps: persistentApps,
            persistentOthers: persistentOthers,
            recentApps: recentApps
        )
    }

    // MARK: - Write

    func saveLayout(_ layout: DockLayout) throws {
        try createBackup()

        var dict = rawPlistDict
        dict["persistent-apps"] = layout.persistentApps.map { serializeItem($0) }
        dict["persistent-others"] = layout.persistentOthers.map { serializeItem($0) }

        let data = try PropertyListSerialization.data(
            fromPropertyList: dict, format: .binary, options: 0
        )
        try data.write(to: plistURL, options: .atomic)
    }

    func reloadDock() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw DockPlistError.killallFailed(error)
        }
    }

    // MARK: - Backup

    func createBackup() throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = backupDir.appendingPathComponent("com.apple.dock.\(timestamp).plist")
        try fileManager.copyItem(at: plistURL, to: backupURL)
        pruneBackups()
    }

    private func pruneBackups() {
        let backups = (try? fileManager.contentsOfDirectory(
            at: backupDir, includingPropertiesForKeys: [.creationDateKey]
        )) ?? []
        let sorted = backups.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return dateA > dateB
        }
        if sorted.count > maxBackups {
            for url in sorted.dropFirst(maxBackups) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - Parse

    private func parseItems(_ items: [[String: Any]]) -> [DockItem] {
        items.compactMap { parseItem($0) }
    }

    private func parseItem(_ dict: [String: Any]) -> DockItem? {
        guard let tileTypeStr = dict["tile-type"] as? String,
              let tileType = TileType(rawValue: tileTypeStr) else {
            return nil
        }

        let guid = (dict["GUID"] as? UInt32) ?? 0
        let tileData = dict["tile-data"] as? [String: Any] ?? [:]
        let fileData = tileData["file-data"] as? [String: Any] ?? [:]
        let urlString = fileData["_CFURLString"] as? String ?? ""
        let label = tileData["file-label"] as? String
            ?? tileData["label"] as? String
            ?? URL(fileURLWithPath: urlString).lastPathComponent
        let bundleId = tileData["bundle-identifier"] as? String

        let url: URL
        if urlString.hasPrefix("file://") {
            url = URL(string: urlString) ?? URL(fileURLWithPath: urlString)
        } else {
            url = URL(fileURLWithPath: urlString)
        }

        var item = DockItem(
            guid: guid,
            tileType: tileType,
            label: label,
            path: url,
            bundleIdentifier: bundleId,
            rawPlistData: dict
        )
        item.loadIcon()
        return item
    }

    // MARK: - Serialize

    private func serializeItem(_ item: DockItem) -> [String: Any] {
        var dict = item.rawPlistData
        dict["GUID"] = item.guid
        dict["tile-type"] = item.tileType.rawValue

        if var tileData = dict["tile-data"] as? [String: Any] {
            var fileData = tileData["file-data"] as? [String: Any] ?? [:]
            let pathStr = item.path.absoluteString.hasPrefix("file://")
                ? item.path.absoluteString
                : "file://\(item.path.path(percentEncoded: false))"
            fileData["_CFURLString"] = pathStr
            fileData["_CFURLStringType"] = 15
            tileData["file-data"] = fileData
            tileData["file-label"] = item.label
            if let bid = item.bundleIdentifier {
                tileData["bundle-identifier"] = bid
            }
            dict["tile-data"] = tileData
        }

        return dict
    }
}
