import XCTest
@testable import DockDIY

final class DockLauncherServiceTests: XCTestCase {
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(
            at: DockLauncherService.shared.launchersDirectory.appendingPathComponent("开发.app")
        )
        try super.tearDownWithError()
    }

    func testLauncherBundleNameIsSanitizedForUnsafeCharacters() {
        let group = DockGroup(
            name: "Dev/Design: Tools",
            folderPath: URL(fileURLWithPath: "/tmp/DockDIY Test/Dev Tools"),
            showAs: .list
        )

        let url = DockLauncherService.shared.launcherAppURL(for: group)

        XCTAssertEqual(url.lastPathComponent, "Dev-Design- Tools.app")
    }

    func testGeneratedScriptOpensItemsFromGroupFolder() {
        let group = DockGroup(
            name: "Design",
            folderPath: URL(fileURLWithPath: "/Applications"),
            showAs: .grid
        )

        let script = DockLauncherService.shared.appleScriptSource(for: group)

        XCTAssertTrue(script.contains("on reopen"))
        XCTAssertTrue(script.contains("open location \"dockdiy://popup?"))
        XCTAssertTrue(script.contains("path=/Applications"))
        XCTAssertFalse(script.contains("style="))
        XCTAssertFalse(script.contains("NSMenu"))
    }

    func testCreateLauncherSupportsLocalizedGroupNames() throws {
        let groupFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockDIYLocalizedGroup", isDirectory: true)
        try FileManager.default.createDirectory(at: groupFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: groupFolder) }

        let group = DockGroup(
            name: "开发",
            folderPath: groupFolder,
            showAs: .list
        )

        let appURL = try DockLauncherService.shared.createLauncher(for: group)

        XCTAssertTrue(FileManager.default.fileExists(atPath: appURL.path(percentEncoded: false)))
        XCTAssertEqual(appURL.lastPathComponent, "开发.app")
    }

    func testCreateLauncherAppliesSelectedCommonIcon() throws {
        let groupFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockDIYIconGroup", isDirectory: true)
        try FileManager.default.createDirectory(at: groupFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: groupFolder) }

        let group = DockGroup(
            name: "Icon Test",
            folderPath: groupFolder,
            showAs: .list,
            iconSystemName: "terminal"
        )

        let appURL = try DockLauncherService.shared.createLauncher(for: group)
        let iconURL = appURL.appendingPathComponent("Contents/Resources/DockDIYLauncher.icns")
        let appletIconURL = appURL.appendingPathComponent("Contents/Resources/applet.icns")
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let plist = NSDictionary(contentsOf: plistURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: appletIconURL.path(percentEncoded: false)))
        XCTAssertEqual(plist?["CFBundleIconFile"] as? String, "DockDIYLauncher")
        XCTAssertNil(plist?["CFBundleIconName"])
    }
}
