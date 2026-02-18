import SwiftUI
import SwiftData

@main
struct TrakkeApp: App {
    @State private var showSplash = true
    let modelContainer: ModelContainer

    init() {
        // Ensure Application Support directory exists before SwiftData
        // creates its store. Without this, CoreData logs errors on first
        // launch before auto-recovering by creating the directory itself.
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            }
        }

        do {
            let schema = Schema([Route.self, Waypoint.self, Project.self, DownloadedArea.self])
            let config = ModelConfiguration(
                schema: schema,
                url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Trakke.store"),
                allowsSave: true
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])

            // Protect the data store with NSFileProtectionComplete
            // so user location data (routes, waypoints) is encrypted at rest
            let storeURL = config.url
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: storeURL.path
            )
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)
                    .preferredColorScheme(.light)

                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
