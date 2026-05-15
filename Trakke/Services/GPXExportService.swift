import Foundation
import OSLog

enum GPXExportService {
    static func exportRoute(_ route: Route, waypoints: [Waypoint] = []) -> String {
        // Pre-size the parts buffer: ~6 lines per waypoint + 4 framing lines + 1 line per trackpoint.
        var parts: [String] = []
        parts.reserveCapacity(waypoints.count * 6 + 4 + route.coordinates.count)

        for wp in waypoints {
            guard wp.coordinates.count >= 2 else { continue }
            let lon = wp.coordinates[0]
            let lat = wp.coordinates[1]
            guard lon.isFinite, lat.isFinite else { continue }
            parts.append("\n  <wpt lat=\"\(lat)\" lon=\"\(lon)\">")
            if let elevation = wp.elevation {
                parts.append("\n    <ele>\(elevation)</ele>")
            }
            parts.append("\n    <time>\(iso8601(wp.createdAt))</time>")
            parts.append("\n    <name>\(escapeXML(wp.name))</name>")
            if let category = wp.category {
                parts.append("\n    <type>\(escapeXML(category))</type>")
            }
            parts.append("\n  </wpt>")
        }

        parts.append("\n  <trk>")
        parts.append("\n    <name>\(escapeXML(route.name))</name>")
        parts.append("\n    <trkseg>")

        for coord in route.coordinates {
            guard coord.count >= 2 else { continue }
            let lon = coord[0]
            let lat = coord[1]
            guard lon.isFinite, lat.isFinite else { continue }
            parts.append("\n      <trkpt lat=\"\(lat)\" lon=\"\(lon)\"></trkpt>")
        }

        parts.append("\n    </trkseg>")
        parts.append("\n  </trk>")

        return gpxDocument(name: route.name, createdAt: route.createdAt, body: parts.joined())
    }

    static func exportWaypoints(_ waypoints: [Waypoint], name: String = "Mine steder") -> String {
        let sorted = waypoints.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var parts: [String] = []
        parts.reserveCapacity(sorted.count * 6)

        for wp in sorted {
            guard wp.coordinates.count >= 2 else { continue }
            let lon = wp.coordinates[0]
            let lat = wp.coordinates[1]
            guard lon.isFinite, lat.isFinite else { continue }
            parts.append("\n  <wpt lat=\"\(lat)\" lon=\"\(lon)\">")
            if let elevation = wp.elevation {
                parts.append("\n    <ele>\(elevation)</ele>")
            }
            parts.append("\n    <time>\(iso8601(wp.createdAt))</time>")
            parts.append("\n    <name>\(escapeXML(wp.name))</name>")
            if let category = wp.category {
                parts.append("\n    <type>\(escapeXML(category))</type>")
            }
            parts.append("\n  </wpt>")
        }

        return gpxDocument(name: name, createdAt: Date(), body: parts.joined())
    }

    static func exportActivity(_ activity: Activity) -> String {
        var parts: [String] = []
        parts.reserveCapacity(activity.trackPoints.count * 4 + 4)
        parts.append("\n  <trk>")
        parts.append("\n    <name>\(escapeXML(activity.name))</name>")
        parts.append("\n    <trkseg>")

        for point in activity.trackPoints {
            guard point.count >= 2 else { continue }
            let lon = point[0]
            let lat = point[1]
            guard lon.isFinite, lat.isFinite else { continue }
            parts.append("\n      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">")
            if point.count >= 3, point[2].isFinite {
                parts.append("\n        <ele>\(point[2])</ele>")
            }
            if point.count >= 4, point[3].isFinite {
                parts.append("\n        <time>\(iso8601(Date(timeIntervalSince1970: point[3])))</time>")
            }
            parts.append("\n      </trkpt>")
        }

        parts.append("\n    </trkseg>")
        parts.append("\n  </trk>")

        return gpxDocument(name: activity.name, createdAt: activity.startedAt, body: parts.joined())
    }

    static func sanitizeFilename(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "[^a-zA-ZæøåÆØÅ0-9\\-_]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return (cleaned.isEmpty ? "rute" : cleaned) + ".gpx"
    }

    /// Directory used for exported files that will be handed to the system
    /// Share Sheet. We avoid the per-process tmp directory because LaunchServices
    /// can't always map a file there to a file provider domain, producing a
    /// cascade of "Failed to request default share mode" and "error fetching
    /// item" warnings in the console. Documents/Exports is a stable, indexable
    /// location LaunchServices can reason about, and it's also visible to the
    /// user in the Files app (via LSSupportsOpeningDocumentsInPlace) so they can
    /// retrieve a recent export if needed.
    static let exportsDirectoryName = "Exports"

    static var exportsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent(exportsDirectoryName, isDirectory: true)
    }

    static func writeToTemporaryFile(gpxString: String, filename: String) -> URL? {
        let dir = exportsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try gpxString.write(to: fileURL, atomically: true, encoding: .utf8)
            // .completeUntilFirstUserAuthentication: encrypted at rest but readable
            // by the system Share Sheet once the device has been unlocked since
            // boot. Stricter protection (.complete) breaks the share extensions.
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            return fileURL
        } catch {
            Logger.routes.error("GPX export write failed: \(error, privacy: .private)")
            return nil
        }
    }

    /// Removes ALL files in Documents/Exports. Used by GDPR "Slett alle data" flow.
    static func clearAllExports() {
        let dir = exportsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Removes export files older than 24h. Called from `TrakkeApp.init()` to
    /// keep Documents/Exports from growing without bound while still letting the
    /// user pick up a recent export from the Files app.
    static func pruneOldExports() {
        let dir = exportsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        for file in files {
            guard let mod = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate else { continue }
            if mod < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Helpers

    private static func gpxDocument(name: String, createdAt: Date, body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Tråkke"
          xmlns="http://www.topografix.com/GPX/1/1"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(name))</name>
            <time>\(iso8601(createdAt))</time>
          </metadata>\(body)
        </gpx>
        """
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func iso8601(_ date: Date) -> String {
        date.ISO8601Format()
    }
}
