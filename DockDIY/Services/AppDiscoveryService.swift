import Foundation
import AppKit

struct AppInfo: Identifiable {
    var id: URL { path }
    let name: String
    let path: URL
    let bundleIdentifier: String?
    let icon: NSImage?
}

final class AppDiscoveryService {

    static let shared = AppDiscoveryService()

    func discoverApps(in directories: [URL]? = nil) -> [AppInfo] {
        let searchDirs = directories ?? [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
        ]

        var apps: [AppInfo] = []
        let fm = FileManager.default

        for dir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                if url.pathExtension == "app" {
                    if let info = appInfo(from: url) {
                        apps.append(info)
                    }
                }
                // Also search one level deeper for subfolders in /Applications
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDir),
                   isDir.boolValue, url.pathExtension != "app" {
                    if let subContents = try? fm.contentsOfDirectory(
                        at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
                    ) {
                        for subURL in subContents where subURL.pathExtension == "app" {
                            if let info = appInfo(from: subURL) {
                                apps.append(info)
                            }
                        }
                    }
                }
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func appInfo(from appURL: URL) -> AppInfo? {
        guard let bundle = Bundle(url: appURL) else { return nil }
        let name = (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let bundleId = bundle.bundleIdentifier
        let icon = IconCache.shared.icon(for: appURL)

        return AppInfo(
            name: name,
            path: appURL,
            bundleIdentifier: bundleId,
            icon: icon
        )
    }
}
