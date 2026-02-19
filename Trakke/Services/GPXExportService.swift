import Foundation

enum GPXExportService {
    static func exportRoute(_ route: Route, waypoints: [Waypoint] = []) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Tråkke"
          xmlns="http://www.topografix.com/GPX/1/1"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(route.name))</name>
            <time>\(iso8601(route.createdAt))</time>
          </metadata>
        """

        // Waypoints
        for wp in waypoints {
            guard wp.coordinates.count >= 2 else { continue }
            let lon = wp.coordinates[0]
            let lat = wp.coordinates[1]
            gpx += "\n  <wpt lat=\"\(lat)\" lon=\"\(lon)\">"
            if let elevation = wp.elevation {
                gpx += "\n    <ele>\(elevation)</ele>"
            }
            gpx += "\n    <time>\(iso8601(wp.createdAt))</time>"
            gpx += "\n    <name>\(escapeXML(wp.name))</name>"
            if let category = wp.category {
                gpx += "\n    <type>\(escapeXML(category))</type>"
            }
            gpx += "\n  </wpt>"
        }

        // Track
        gpx += "\n  <trk>"
        gpx += "\n    <name>\(escapeXML(route.name))</name>"
        gpx += "\n    <trkseg>"

        for coord in route.coordinates {
            guard coord.count >= 2 else { continue }
            let lon = coord[0]
            let lat = coord[1]
            gpx += "\n      <trkpt lat=\"\(lat)\" lon=\"\(lon)\"></trkpt>"
        }

        gpx += "\n    </trkseg>"
        gpx += "\n  </trk>"
        gpx += "\n</gpx>\n"

        return gpx
    }

    static func exportWaypoints(_ waypoints: [Waypoint], name: String = "Mine steder") -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Tråkke"
          xmlns="http://www.topografix.com/GPX/1/1"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(name))</name>
            <time>\(iso8601(Date()))</time>
          </metadata>
        """

        let sorted = waypoints.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        for wp in sorted {
            guard wp.coordinates.count >= 2 else { continue }
            let lon = wp.coordinates[0]
            let lat = wp.coordinates[1]
            gpx += "\n  <wpt lat=\"\(lat)\" lon=\"\(lon)\">"
            if let elevation = wp.elevation {
                gpx += "\n    <ele>\(elevation)</ele>"
            }
            gpx += "\n    <time>\(iso8601(wp.createdAt))</time>"
            gpx += "\n    <name>\(escapeXML(wp.name))</name>"
            if let category = wp.category {
                gpx += "\n    <type>\(escapeXML(category))</type>"
            }
            gpx += "\n  </wpt>"
        }

        gpx += "\n</gpx>\n"
        return gpx
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
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

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
