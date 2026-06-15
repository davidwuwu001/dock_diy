import XCTest
@testable import DockDIY

final class DockViewModelGroupTests: XCTestCase {
    func testVisibleGroupsExcludeLegacyDockRightSideFolders() {
        let legacyFolder = DockItem(
            guid: 12,
            tileType: .directory,
            label: "Legacy Stack",
            path: URL(fileURLWithPath: "/tmp/legacy-stack"),
            rawPlistData: [:]
        )
        let layout = DockLayout(
            persistentApps: [],
            persistentOthers: [legacyFolder],
            recentApps: []
        )

        let groups = DockViewModel.visibleGroups(
            managedGroups: [],
            layout: layout
        )

        XCTAssertTrue(groups.isEmpty)
    }
}
