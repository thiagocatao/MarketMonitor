import SwiftUI

@main
struct MarketMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { EmptyView().frame(width: 0, height: 0) }
            .windowResizability(.contentSize)
    }
}
