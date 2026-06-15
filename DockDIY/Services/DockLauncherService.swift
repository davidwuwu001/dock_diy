import Foundation
import AppKit

enum DockLauncherError: LocalizedError {
    case compileFailed(String)
    case codeSignFailed(String)
    case iconFailed(String)

    var errorDescription: String? {
        switch self {
        case .compileFailed(let message):
            return "生成 Dock 图标失败: \(message)"
        case .codeSignFailed(let message):
            return "签名 Dock 图标失败: \(message)"
        case .iconFailed(let message):
            return "生成 Dock 图标图片失败: \(message)"
        }
    }
}

final class DockLauncherService {
    static let shared = DockLauncherService()

    private let fileManager = FileManager.default

    var launchersDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/DockDIY Launchers")
    }

    func launcherAppURL(for group: DockGroup) -> URL {
        launchersDirectory.appendingPathComponent("\(safeAppName(for: group.name)).app")
    }

    func createLauncher(for group: DockGroup) throws -> URL {
        try fileManager.createDirectory(at: launchersDirectory, withIntermediateDirectories: true)

        let appURL = launcherAppURL(for: group)
        if fileManager.fileExists(atPath: appURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: appURL)
        }

        let buildDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("DockDIYLauncher-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: buildDirectory) }

        let scriptURL = buildDirectory.appendingPathComponent("launcher.applescript")
        let temporaryAppURL = buildDirectory.appendingPathComponent("Launcher.app")
        try appleScriptSource(for: group).write(to: scriptURL, atomically: true, encoding: .utf8)

        try runProcess(
            executable: "/usr/bin/osacompile",
            arguments: ["-o", temporaryAppURL.path(percentEncoded: false), scriptURL.path(percentEncoded: false)],
            failure: DockLauncherError.compileFailed
        )

        try fileManager.moveItem(at: temporaryAppURL, to: appURL)
        try configureInfoPlist(for: group, appURL: appURL)
        try createLauncherIcon(for: group, appURL: appURL, buildDirectory: buildDirectory)

        try? runProcess(executable: "/usr/bin/xattr", arguments: ["-cr", appURL.path(percentEncoded: false)]) {
            DockLauncherError.codeSignFailed($0)
        }
        try runProcess(executable: "/usr/bin/codesign", arguments: ["--force", "--sign", "-", appURL.path(percentEncoded: false)]) {
            DockLauncherError.codeSignFailed($0)
        }

        return appURL
    }

    func revealLauncher(for group: DockGroup) throws {
        let appURL = try createLauncher(for: group)
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    func appleScriptSource(for group: DockGroup) -> String {
        let popupURL = escapedAppleScriptString(popupURLString(for: group))

        return """
        use scripting additions

        on run
            open location "\(popupURL)"
        end run

        on reopen
            open location "\(popupURL)"
        end reopen
        """
    }

    private func configureInfoPlist(for group: DockGroup, appURL: URL) throws {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let bundleId = "com.dockdiy.launcher.\(safeBundleSuffix(for: group.name))"
        try setPlistValue(plistURL, key: "CFBundleIdentifier", value: bundleId)
        try setPlistValue(plistURL, key: "CFBundleName", value: group.name)
        try addPlistBool(plistURL, key: "LSUIElement", value: true)
        try addPlistString(
            plistURL,
            key: "NSAppleEventsUsageDescription",
            value: "DockDIY launcher needs permission to open items in this group."
        )
        try deletePlistKey(plistURL, key: "CFBundleIconName")
        try setPlistValue(plistURL, key: "CFBundleIconFile", value: "DockDIYLauncher")
    }

    private func createLauncherIcon(for group: DockGroup, appURL: URL, buildDirectory: URL) throws {
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let defaultAssetCatalogURL = resourcesURL.appendingPathComponent("Assets.car")
        if fileManager.fileExists(atPath: defaultAssetCatalogURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: defaultAssetCatalogURL)
        }

        let iconsetURL = buildDirectory.appendingPathComponent("DockDIYLauncher.iconset", isDirectory: true)
        try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        let iconFiles: [(name: String, points: CGFloat, scale: CGFloat)] = [
            ("icon_16x16.png", 16, 1),
            ("icon_16x16@2x.png", 16, 2),
            ("icon_32x32.png", 32, 1),
            ("icon_32x32@2x.png", 32, 2),
            ("icon_128x128.png", 128, 1),
            ("icon_128x128@2x.png", 128, 2),
            ("icon_256x256.png", 256, 1),
            ("icon_256x256@2x.png", 256, 2),
            ("icon_512x512.png", 512, 1),
            ("icon_512x512@2x.png", 512, 2)
        ]

        for iconFile in iconFiles {
            let pixelSize = Int(iconFile.points * iconFile.scale)
            let image = launcherIconImage(
                systemName: group.iconSystemName,
                pixelSize: pixelSize
            )
            guard let data = pngData(for: image, pixelSize: pixelSize) else {
                throw DockLauncherError.iconFailed("无法渲染 \(iconFile.name)")
            }
            try data.write(to: iconsetURL.appendingPathComponent(iconFile.name))
        }

        let launcherIconURL = resourcesURL.appendingPathComponent("DockDIYLauncher.icns")

        try runProcess(
            executable: "/usr/bin/iconutil",
            arguments: [
                "-c", "icns",
                "-o", launcherIconURL.path(percentEncoded: false),
                iconsetURL.path(percentEncoded: false)
            ],
            failure: DockLauncherError.iconFailed
        )

        let appletIconURL = resourcesURL.appendingPathComponent("applet.icns")
        if fileManager.fileExists(atPath: appletIconURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: appletIconURL)
        }
        try fileManager.copyItem(at: launcherIconURL, to: appletIconURL)

        if let icon = NSImage(contentsOf: launcherIconURL) {
            NSWorkspace.shared.setIcon(icon, forFile: appURL.path(percentEncoded: false), options: [])
        }
    }

    private func launcherIconImage(systemName: String, pixelSize: Int) -> NSImage {
        let size = NSSize(width: pixelSize, height: pixelSize)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        let bounds = NSRect(origin: .zero, size: size)
        NSColor(calibratedRed: 0.13, green: 0.38, blue: 0.92, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: size.width * 0.22, yRadius: size.height * 0.22).fill()

        NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
        NSBezierPath(
            roundedRect: bounds.insetBy(dx: size.width * 0.08, dy: size.height * 0.08),
            xRadius: size.width * 0.16,
            yRadius: size.height * 0.16
        ).fill()

        let symbolName = DockGroup.iconOptions.contains(where: { $0.systemName == systemName })
            ? systemName
            : DockGroup.defaultIconSystemName
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: DockGroup.defaultIconSystemName, accessibilityDescription: nil)

        if let symbol {
            let symbolSide = size.width * 0.56
            let symbolRect = NSRect(
                x: (size.width - symbolSide) / 2,
                y: (size.height - symbolSide) / 2,
                width: symbolSide,
                height: symbolSide
            )
            NSColor.white.set()
            symbol.draw(
                in: symbolRect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }

        return image
    }

    private func pngData(for image: NSImage, pixelSize: Int) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        bitmap.size = NSSize(width: pixelSize, height: pixelSize)
        return bitmap.representation(using: .png, properties: [:])
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        failure: (String) -> DockLauncherError
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw failure(message)
        }
    }

    private func setPlistValue(_ plistURL: URL, key: String, value: String) throws {
        try? runProcess(executable: "/usr/libexec/PlistBuddy", arguments: ["-c", "Delete :\(key)", plistURL.path(percentEncoded: false)]) {
            DockLauncherError.compileFailed($0)
        }
        try runProcess(executable: "/usr/libexec/PlistBuddy", arguments: ["-c", "Add :\(key) string \(value)", plistURL.path(percentEncoded: false)]) {
            DockLauncherError.compileFailed($0)
        }
    }

    private func deletePlistKey(_ plistURL: URL, key: String) throws {
        try? runProcess(executable: "/usr/libexec/PlistBuddy", arguments: ["-c", "Delete :\(key)", plistURL.path(percentEncoded: false)]) {
            DockLauncherError.compileFailed($0)
        }
    }

    private func addPlistBool(_ plistURL: URL, key: String, value: Bool) throws {
        try? runProcess(executable: "/usr/libexec/PlistBuddy", arguments: ["-c", "Delete :\(key)", plistURL.path(percentEncoded: false)]) {
            DockLauncherError.compileFailed($0)
        }
        try runProcess(executable: "/usr/libexec/PlistBuddy", arguments: ["-c", "Add :\(key) bool \(value ? "true" : "false")", plistURL.path(percentEncoded: false)]) {
            DockLauncherError.compileFailed($0)
        }
    }

    private func addPlistString(_ plistURL: URL, key: String, value: String) throws {
        try? runProcess(executable: "/usr/libexec/PlistBuddy", arguments: ["-c", "Delete :\(key)", plistURL.path(percentEncoded: false)]) {
            DockLauncherError.compileFailed($0)
        }
        try runProcess(executable: "/usr/libexec/PlistBuddy", arguments: ["-c", "Add :\(key) string \(value)", plistURL.path(percentEncoded: false)]) {
            DockLauncherError.compileFailed($0)
        }
    }

    private func popupURLString(for group: DockGroup) -> String {
        var components = URLComponents()
        components.scheme = "dockdiy"
        components.host = "popup"
        components.queryItems = [
            URLQueryItem(name: "name", value: group.name),
            URLQueryItem(name: "path", value: normalizedPath(group.folderPath))
        ]
        return components.url?.absoluteString ?? "dockdiy://popup"
    }

    private func safeAppName(for name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:")
        let sanitized = name
            .components(separatedBy: illegal)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "DockDIY Launcher" : sanitized
    }

    private func safeBundleSuffix(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let mapped = name.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let suffix = String(mapped).split(separator: "-").joined(separator: "-")
        return suffix.isEmpty ? "group" : suffix
    }

    private func escapedAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func normalizedPath(_ url: URL) -> String {
        let path = url.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
