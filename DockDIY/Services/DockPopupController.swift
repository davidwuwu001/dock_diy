import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class DockPopupController: NSObject, NSWindowDelegate {
    static let shared = DockPopupController()

    private var panel: NSPanel?

    func handle(_ url: URL) {
        guard url.scheme == "dockdiy", url.host == "popup",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )
        let name = items["name"] ?? "DockDIY"
        guard let path = items["path"] else { return }
        let styleValue = Int(items["style"] ?? "") ?? StackDisplayStyle.grid.rawValue
        let folderURL = URL(fileURLWithPath: path)
        let fallbackStyle = StackDisplayStyle(rawValue: styleValue) ?? .grid
        let style = GroupManager.shared.displayStyle(for: folderURL)
        showPopup(name: name, folderURL: folderURL, style: style == .auto ? fallbackStyle : style)
    }

    func showPopup(name: String, folderURL: URL, style: StackDisplayStyle) {
        panel?.close()

        let view = DockPopupView(
            title: name,
            folderURL: folderURL,
            style: style,
            onStyleChange: { folderURL, style in
                try? GroupManager.shared.updateDisplayStyle(for: folderURL, showAs: style)
            },
            onClose: { [weak self] in self?.panel?.close() }
        )
        let hosting = NSHostingView(rootView: view)
        let size = style == .list
            ? NSSize(width: 340, height: 420)
            : NSSize(width: 430, height: 430)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        position(panel, size: size)
        self.panel = panel
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        panel?.close()
    }

    private func position(_ panel: NSPanel, size: NSSize) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = min(max(mouse.x - size.width / 2, visibleFrame.minX + 12), visibleFrame.maxX - size.width - 12)
        let y = max(visibleFrame.minY + 18, mouse.y + 18)
        panel.setFrameOrigin(NSPoint(x: x, y: min(y, visibleFrame.maxY - size.height - 12)))
    }
}
