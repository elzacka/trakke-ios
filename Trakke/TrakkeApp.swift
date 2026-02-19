import SwiftUI
import SwiftData
import os
@preconcurrency import MapLibre

// MARK: - MapLibre User-Agent Fix

/// MapLibre builds its User-Agent from CFBundleName ("Trakke" with a).
/// IIS-based servers (e.g. Miljodirektoratet ArcGIS) return HTTP 500
/// when headers contain non-ASCII characters. This delegate sanitizes
/// the User-Agent to ASCII before each request.
///
/// @unchecked Sendable is safe: this class has no stored mutable state.
/// willSend is called from MapLibre's network thread; only the request parameter is mutated.
private final class MapLibreHeaderSanitizer: NSObject, MLNNetworkConfigurationDelegate, @unchecked Sendable {
    func willSend(_ request: NSMutableURLRequest) -> NSMutableURLRequest {
        if let ua = request.value(forHTTPHeaderField: "User-Agent"),
           let ascii = ua.data(using: .ascii) {
            // Already ASCII-safe
            _ = ascii
        } else if let ua = request.value(forHTTPHeaderField: "User-Agent") {
            // Contains non-ASCII; transliterate to ASCII
            let safe = ua.applyingTransform(.toLatin, reverse: false)
                .flatMap { $0.applyingTransform(.stripDiacritics, reverse: false) }
                ?? ua.unicodeScalars.filter { $0.isASCII }.map { String($0) }.joined()
            request.setValue(safe, forHTTPHeaderField: "User-Agent")
        }
        return request
    }
}

private let headerSanitizer = MapLibreHeaderSanitizer()
private let logger = Logger(subsystem: "no.tazk.trakke", category: "App")

@main
struct TrakkeApp: App {
    @State private var showSplash = true
    let modelContainer: ModelContainer

    init() {
        MLNNetworkConfiguration.sharedManager.delegate = headerSanitizer

        let fileManager = FileManager.default

        // Ensure Application Support directory exists
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Application Support directory not available")
        }

        if !fileManager.fileExists(atPath: appSupportURL.path) {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }

        // Protect the entire Application Support directory so all files
        // (including .store-wal and .store-shm) inherit NSFileProtectionComplete
        do {
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: appSupportURL.path
            )
        } catch {
            logger.error("Failed to set file protection on Application Support: \(error, privacy: .private)")
        }

        let storeURL = appSupportURL.appendingPathComponent("Trakke.store")

        // Create ModelContainer with versioned schema and migration plan
        do {
            let config = ModelConfiguration(
                url: storeURL,
                allowsSave: true
            )
            modelContainer = try ModelContainer(
                for: Route.self, Waypoint.self,
                migrationPlan: TrakkeMigrationPlan.self,
                configurations: config
            )
        } catch {
            logger.error("SwiftData ModelContainer failed, attempting recovery: \(error, privacy: .private)")

            // Recovery: delete corrupted store and create fresh
            let storeFiles = [
                storeURL,
                storeURL.appendingPathExtension("wal"),
                storeURL.appendingPathExtension("shm"),
            ]
            for file in storeFiles {
                try? fileManager.removeItem(at: file)
            }

            do {
                let config = ModelConfiguration(
                    url: storeURL,
                    allowsSave: true
                )
                modelContainer = try ModelContainer(
                    for: Route.self, Waypoint.self,
                    migrationPlan: TrakkeMigrationPlan.self,
                    configurations: config
                )
                logger.info("SwiftData recovery successful -- created fresh store")
            } catch {
                fatalError("Failed to create SwiftData ModelContainer after recovery attempt")
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .preferredColorScheme(.light)

                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.6))
                if reduceMotion {
                    showSplash = false
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
