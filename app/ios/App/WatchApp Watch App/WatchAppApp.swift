import SwiftUI

@main
struct WatchApp_Watch_AppApp: App {

    @StateObject private var coordinator = RecordingCoordinator.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}
