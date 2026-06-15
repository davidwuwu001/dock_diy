import SwiftUI
import AppKit

@MainActor
final class DockDIYAppDelegate: NSObject, NSApplicationDelegate {
    private let launchDate = Date()

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handle)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                         withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        handle(url)
    }

    private func handle(_ url: URL) {
        let coldPopupLaunch = Date().timeIntervalSince(launchDate) < 3
        DockPopupController.shared.handle(url)
        if coldPopupLaunch, url.scheme == "dockdiy", url.host == "popup" {
            suppressAutomaticMainWindow()
        }
    }

    private func suppressAutomaticMainWindow() {
        for delay in [0.05, 0.2, 0.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSApp.windows
                    .filter { !($0 is NSPanel) }
                    .filter { $0.title.isEmpty || $0.title == "DockDIY" }
                    .forEach { $0.close() }
            }
        }
    }
}

@main
struct DockDIYApp: App {
    @NSApplicationDelegateAdaptor(DockDIYAppDelegate.self) private var appDelegate
    @State private var viewModel = DockViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
    }
}
