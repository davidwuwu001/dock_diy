import SwiftUI

@main
struct DockDIYApp: App {
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
