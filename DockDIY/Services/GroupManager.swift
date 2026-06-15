import Foundation
import AppKit

final class GroupManager {

    static let shared = GroupManager()

    private let fileManager = FileManager.default

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

    // MARK: - Rename Group

    func renameGroup(oldName: String, newName: String) throws {
        let oldURL = groupsDirectory.appendingPathComponent(oldName)
        let newURL = groupsDirectory.appendingPathComponent(newName)
        try fileManager.moveItem(at: oldURL, to: newURL)
    }
}
