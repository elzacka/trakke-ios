import SwiftUI
import SwiftData

@main
struct TrakkeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Route.self,
            Waypoint.self,
            Project.self,
            DownloadedArea.self,
        ])
    }
}
