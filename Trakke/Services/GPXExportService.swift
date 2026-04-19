import Foundation
import OSLog

enum GPXExportService {
    static func exportRoute(_ route: Route, waypoints: [Waypoint] = []) -> String {
        var body = ""

        for wp in waypoints {
            guard wp.coordinates.count >= 2 else { continue }
            let lon = wp.coordinates[0]
            let lat = wp.coordinates[1]
            guard lon.isFinite, lat.isFinite else { continue }
            body += "\n  <wpt lat=\"\(lat)\" lon=\"\(lon)\">"
            if let elevation = wp.elevation {
                body += "\n    <ele>\(elevation)</ele>"
            }
            body += "\n    <time>\(iso8601(wp.createdAt))</time>"
            body += "\n    <name>\(escapeXML(wp.name))</name>"
            if let category = wp.category {
                body += "\n    <type>\(escapeXML(category))</type>"
            }
            body += "\n  </wpt>"
        }

        body += "\n  <trk>"
        body += "\n    <name>\(escapeXML(route.name))</name>"
        body += "\n    <trkseg>"

        for coord in route.coordinates {
            guard coord.count >= 2 else { continue }
            let lon = coord[0]
            let lat = coord[1]
            guard lon.isFinite, lat.isFinite else { continue }
            body += "\n      <trkpt lat=\"\(lat)\" lon=\"\(lon)\"></trkpt>"
        }

        body += "\n    </trkseg>"
        body += "\n  </trk>"

        return gpxDocument(name: route.name, createdAt: route.createdAt, body: body)
    }

    static func exportWaypoints(_ waypoints: [Waypoint], name: String = "Mine steder") -> String {
        var body = ""

        let sorted = waypoints.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        for wp in sorted {
            guard wp.coordinates.count >= 2 else { continue }
            let lon = wp.coordinates[0]
            let lat = wp.coordinates[1]
            guard lon.isFinite, lat.isFinite else { continue }
            body += "\n  <wpt lat=\"\(lat)\" lon=\"\(lon)\">"
            if let elevation = wp.elevation {
                body += "\n    <ele>\(elevation)</ele>"
            }
            body += "\n    <time>\(iso8601(wp.createdAt))</time>"
            body += "\n    <name>\(escapeXML(wp.name))</name>"
            if let category = wp.category {
                body += "\n    <type>\(escapeXML(category))</type>"
            }
            body += "\n  </wpt>"
        }

        return gpxDocument(name: name, createdAt: Date(), body: body)
    }

    static func exportActivity(_ activity: Activity) -> String {
        var body = "\n  <trk>"
        body += "\n    <name>\(escapeXML(activity.name))</name>"
        body += "\n    <trkseg>"

        for point in activity.trackPoints {
            guard point.count >= 2 else { continue }
            let lon = point[0]
            let lat = point[1]
            guard lon.isFinite, lat.isFinite else { continue }
            body += "\n      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">"
            if point.count >= 3, point[2].isFinite {
                body += "\n        <ele>\(point[2])</ele>"
            }
            if point.count >= 4, point[3].isFinite {
                body += "\n        <time>\(iso8601(Date(timeIntervalSince1970: point[3])))</time>"
            }
            body += "\n      </trkpt>"
        }

        body += "\n    </trkseg>"
        body += "\n  </trk>"

        return gpxDocument(name: activity.name, createdAt: activity.startedAt, body: body)
    }

    static func sanitizeFilename(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "[^a-zA-ZæøåÆØÅ0-9\\-_]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return (cleaned.isEmpty ? "rute" : cleaned) + ".gpx"
    }

    static func writeToTemporaryFile(gpxString: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try gpxString.write(to: fileURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
            return fileURL
        } catch {
            Logger.routes.error("GPX export write failed: \(error, privacy: .private)")
            return nil
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
