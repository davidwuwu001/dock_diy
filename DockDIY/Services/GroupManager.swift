import Foundation
import AppKit

final class GroupManager {

    static let shared = GroupManager()

    private let fileManager = FileManager.default
    private let metadataFileName = ".dockdiy.json"

    private struct GroupMetadata: Codable {
        var name: String
        var showAs: StackDisplayStyle
        var arrangement: StackArrangement
        var iconSystemName: String?
    }

    var groupsDirectory: URL {
        let appSupport = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DockDIY")
        return appSupport.appendingPathComponent("groups")
    }

    init() {
        try? fileManager.createDirectory(
            at: groupsDirectory, withIntermediateDirectories: true
        )
    }

    // MARK: - Create / Delete Groups

    func createGroupFolder(name: String) throws -> URL {
        let folderURL = groupsDirectory.appendingPathComponent(name)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }

    func saveMetadata(for groupPath: URL, name: String,
                      showAs: StackDisplayStyle, arrangement: StackArrangement,
                      iconSystemName: String = DockGroup.defaultIconSystemName) throws {
        let metadata = GroupMetadata(
            name: name,
            showAs: showAs,
            arrangement: arrangement,
            iconSystemName: iconSystemName
        )
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: groupPath.appendingPathComponent(metadataFileName), options: .atomic)
    }

    func deleteGroupFolder(at path: URL) throws {
        if fileManager.fileExists(atPath: path.path(percentEncoded: false)) {
            try fileManager.removeItem(at: path)
        }
    }

    // MARK: - Symlink Management

    func addAppToGroup(groupPath: URL, appPath: URL) throws {
        let appName = appPath.lastPathComponent
        let symlinkURL = groupPath.appendingPathComponent(appName)

        guard !fileManager.fileExists(atPath: symlinkURL.path(percentEncoded: false)) else {
            return // Already exists
        }

        try fileManager.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: appPath
        )
    }

    func removeAppFromGroup(groupPath: URL, appName: String) throws {
        let symlinkURL = groupPath.appendingPathComponent(appName)
        let path = symlinkURL.path(percentEncoded: false)

        guard fileManager.fileExists(atPath: path) else { return }

        // Safety: only delete symbolic links, never real .app bundles
        let attrs = try fileManager.attributesOfItem(atPath: path)
        guard let type = attrs[.type] as? FileAttributeType,
              type == .typeSymbolicLink else {
            return // Not a symlink, skip for safety
        }

        try fileManager.removeItem(at: symlinkURL)
    }

    // MARK: - Scan Members

    func scanGroupMembers(groupPath: URL) -> [DockGroupMember] {
        let contents = (try? fileManager.contentsOfDirectory(
            at: groupPath,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents.compactMap { url -> DockGroupMember? in
            let path = url.path(percentEncoded: false)

            // Only include symbolic links
            guard let isSymlink = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
                  isSymlink == true else {
                return nil
            }

            // Resolve the symlink target
            guard let target = try? fileManager.destinationOfSymbolicLink(atPath: path) else {
                return nil
            }

            let targetURL = URL(fileURLWithPath: target)
            let bundleId = Bundle(url: targetURL)?.bundleIdentifier
            let label = targetURL.deletingPathExtension().lastPathComponent

            var member = DockGroupMember(
                appPath: targetURL,
                symlinkPath: url,
                label: label,
                bundleIdentifier: bundleId
            )
            member.loadIcon()
            return member
        }
    }

    func scanManagedGroups() -> [DockGroup] {
        let contents = (try? fileManager.contentsOfDirectory(
            at: groupsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents.compactMap { url -> DockGroup? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }

            let metadata = loadMetadata(groupPath: url)
            let name = metadata?.name ?? url.lastPathComponent
            return DockGroup(
                name: name,
                folderPath: url,
                members: scanGroupMembers(groupPath: url),
                showAs: metadata?.showAs ?? .list,
                arrangement: metadata?.arrangement ?? .name,
                iconSystemName: metadata?.iconSystemName ?? DockGroup.defaultIconSystemName
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - Rename Group

    func renameGroup(oldName: String, newName: String) throws {
        let oldURL = groupsDirectory.appendingPathComponent(oldName)
        let newURL = groupsDirectory.appendingPathComponent(newName)
        try fileManager.moveItem(at: oldURL, to: newURL)
    }

    private func loadMetadata(groupPath: URL) -> GroupMetadata? {
        let url = groupPath.appendingPathComponent(metadataFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GroupMetadata.self, from: data)
    }
}
