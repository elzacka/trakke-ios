import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let geoJSON = UTType("public.geojson")
        ?? UTType(filenameExtension: "geojson", conformingTo: .json)
        ?? .json
}

enum GeoJSONImportService {
    private static let maxFileSize = 50 * 1024 * 1024 // 50 MB

    struct ImportResult: Sendable {
        let waypoints: [GPXImportService.ImportedWaypoint]
        let routes: [GPXImportService.ImportedRoute]
        let activities: [GPXImportService.ImportedActivity]
    }

    enum ImportError: LocalizedError {
        case fileTooLarge(Int)
        case invalidJSON
        case notGeoJSON

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let bytes):
                let mb = bytes / (1024 * 1024)
                return String(localized: "gpx.fileTooLarge \(mb)")
            case .invalidJSON:
                return String(localized: "geojson.invalidJSON")
            case .notGeoJSON:
                return String(localized: "geojson.notGeoJSON")
            }
        }
    }

    static func parse(from url: URL) throws -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard data.count <= maxFileSize else {
            throw ImportError.fileTooLarge(data.count)
        }
        return try parse(data: data)
    }

    static func parse(data: Data) throws -> ImportResult {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError.invalidJSON
        }
        guard let json = parsed as? [String: Any] else {
            throw ImportError.notGeoJSON
        }

        var waypoints: [GPXImportService.ImportedWaypoint] = []
        var routes: [GPXImportService.ImportedRoute] = []
        var activities: [GPXImportService.ImportedActivity] = []

        let type = (json["type"] as? String) ?? ""
        switch type {
        case "FeatureCollection":
            guard let features = json["features"] as? [[String: Any]] else {
                throw ImportError.notGeoJSON
            }
            for feature in features {
                extract(from: feature, into: &waypoints, and: &routes, and: &activities)
            }
        case "Feature":
            extract(from: json, into: &waypoints, and: &routes, and: &activities)
        case "Point", "LineString", "Polygon", "MultiPoint", "MultiLineString", "MultiPolygon":
            // Bare geometry without Feature wrapper — accept it.
            let synthesizedFeature: [String: Any] = [
                "type": "Feature",
                "geometry": json,
                "properties": [:],
            ]
            extract(from: synthesizedFeature, into: &waypoints, and: &routes, and: &activities)
        default:
            throw ImportError.notGeoJSON
        }

        return ImportResult(waypoints: waypoints, routes: routes, activities: activities)
    }

    // MARK: - Feature extraction

    // ISO8601DateFormatter is documented thread-safe for parsing; nonisolated(unsafe)
    // is the standard pattern in this codebase for static date formatters.
    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func extract(
        from feature: [String: Any],
        into waypoints: inout [GPXImportService.ImportedWaypoint],
        and routes: inout [GPXImportService.ImportedRoute],
        and activities: inout [GPXImportService.ImportedActivity]
    ) {
        guard let geometry = feature["geometry"] as? [String: Any],
              let type = geometry["type"] as? String else { return }
        let properties = feature["properties"] as? [String: Any] ?? [:]
        let name = (properties["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case "Point":
            if let coord = geometry["coordinates"] as? [Double],
               let wp = waypoint(from: coord, name: name, properties: properties) {
                waypoints.append(wp)
            }

        case "MultiPoint":
            if let coords = geometry["coordinates"] as? [[Double]] {
                for coord in coords {
                    if let wp = waypoint(from: coord, name: name, properties: properties) {
                        waypoints.append(wp)
                    }
                }
            }

        case "LineString":
            if let coords = geometry["coordinates"] as? [[Double]] {
                // GeoJSON-Track convention: if properties.coordinateProperties.times
                // matches coordinates length, this is an activity track with
                // per-point timestamps. Otherwise it's a planned route.
                if let activity = activity(from: coords, name: name, properties: properties) {
                    activities.append(activity)
                } else if let route = route(from: coords, name: name) {
                    routes.append(route)
                }
            }

        case "MultiLineString":
            if let lines = geometry["coordinates"] as? [[[Double]]] {
                for coords in lines {
                    if let route = route(from: coords, name: name) {
                        routes.append(route)
                    }
                }
            }

        case "Polygon":
            // Outer ring → closed Route. Inner rings (holes) silently dropped:
            // a polyline cannot represent multi-ring topology, and holes are rare
            // in hiking data.
            if let rings = geometry["coordinates"] as? [[[Double]]],
               let outer = rings.first,
               let route = closedRoute(from: outer, name: name) {
                routes.append(route)
            }

        case "MultiPolygon":
            if let polygons = geometry["coordinates"] as? [[[[Double]]]] {
                for rings in polygons {
                    if let outer = rings.first,
                       let route = closedRoute(from: outer, name: name) {
                        routes.append(route)
                    }
                }
            }

        case "GeometryCollection":
            if let geometries = geometry["geometries"] as? [[String: Any]] {
                for inner in geometries {
                    let wrapped: [String: Any] = [
                        "type": "Feature",
                        "geometry": inner,
                        "properties": properties,
                    ]
                    extract(from: wrapped, into: &waypoints, and: &routes, and: &activities)
                }
            }

        default:
            // Unknown geometry — skip silently.
            break
        }
    }

    private static func waypoint(
        from coordinate: [Double],
        name: String?,
        properties: [String: Any]
    ) -> GPXImportService.ImportedWaypoint? {
        guard coordinate.count >= 2 else { return nil }
        let lon = coordinate[0]
        let lat = coordinate[1]
        guard lon.isFinite, lat.isFinite,
              (-90...90).contains(lat),
              (-180...180).contains(lon) else { return nil }
        let elevation: Double? = {
            if coordinate.count >= 3, coordinate[2].isFinite {
                return coordinate[2]
            }
            if let ele = properties["elevation"] as? Double, ele.isFinite {
                return ele
            }
            return nil
        }()
        let category = (properties["category"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (name?.isEmpty == false)
            ? name!
            : String(localized: "waypoints.new")
        return GPXImportService.ImportedWaypoint(
            name: resolvedName,
            latitude: lat,
            longitude: lon,
            elevation: elevation,
            category: (category?.isEmpty == false) ? category : nil
        )
    }

    private static func route(
        from coordinates: [[Double]],
        name: String?
    ) -> GPXImportService.ImportedRoute? {
        let cleaned: [[Double]] = coordinates
            .prefix(GPXImportService.maxPointsPerFeature)
            .compactMap { coord -> [Double]? in
                guard coord.count >= 2 else { return nil }
                let lon = coord[0]
                let lat = coord[1]
                guard lon.isFinite, lat.isFinite,
                      (-90...90).contains(lat),
                      (-180...180).contains(lon) else { return nil }
                // GeoJSON Position is [lon, lat] or [lon, lat, alt]. Preserve
                // altitude when present so the elevation profile renders
                // without a DEM round-trip.
                if coord.count >= 3, coord[2].isFinite {
                    return [lon, lat, coord[2]]
                }
                return [lon, lat]
            }
        guard cleaned.count >= 2 else { return nil }
        let resolvedName = (name?.isEmpty == false)
            ? name!
            : String(localized: "routes.imported")
        return GPXImportService.ImportedRoute(name: resolvedName, coordinates: cleaned)
    }

    /// Returns an `ImportedActivity` when the LineString carries per-point timestamps
    /// via the de-facto GeoJSON-Track convention (`properties.coordinateProperties.times`).
    /// Returns nil otherwise — caller should fall back to importing as a Route.
    private static func activity(
        from coordinates: [[Double]],
        name: String?,
        properties: [String: Any]
    ) -> GPXImportService.ImportedActivity? {
        guard let coordProps = properties["coordinateProperties"] as? [String: Any],
              let times = coordProps["times"] as? [String],
              times.count == coordinates.count else { return nil }

        var points: [[Double]] = []
        var firstDate: Date?
        for (i, coord) in coordinates.enumerated() {
            if points.count >= GPXImportService.maxPointsPerFeature { break }
            guard coord.count >= 2 else { continue }
            let lon = coord[0]
            let lat = coord[1]
            guard lon.isFinite, lat.isFinite,
                  (-90...90).contains(lat),
                  (-180...180).contains(lon) else { continue }
            let elevation = (coord.count >= 3 && coord[2].isFinite) ? coord[2] : 0
            let dateString = times[i]
            let date = iso8601Formatter.date(from: dateString)
                ?? iso8601FormatterNoFraction.date(from: dateString)
                ?? Date.now
            if firstDate == nil { firstDate = date }
            points.append([lon, lat, elevation, date.timeIntervalSince1970])
        }
        guard points.count >= 2 else { return nil }

        // Same heuristic as the GPX parser: real recordings span at least a few
        // seconds. If every timestamp is identical (placeholder export from a
        // planning tool), treat this as a route, not an activity.
        if let first = points.first?.last, let last = points.last?.last,
           (last - first) < 1.0 {
            return nil
        }

        let resolvedName = (name?.isEmpty == false)
            ? name!
            : String(localized: "activity.imported")
        return GPXImportService.ImportedActivity(
            name: resolvedName,
            trackPoints: points,
            startedAt: firstDate ?? Date.now
        )
    }

    private static func closedRoute(
        from outerRing: [[Double]],
        name: String?
    ) -> GPXImportService.ImportedRoute? {
        guard var line = route(from: outerRing, name: name)?.coordinates else { return nil }
        // Ensure the ring is explicitly closed (some GeoJSON writers omit the duplicate
        // closing coordinate; we normalize to a closed polyline).
        if let first = line.first, let last = line.last,
           !(first[0] == last[0] && first[1] == last[1]) {
            line.append(first)
        }
        let resolvedName = (name?.isEmpty == false)
            ? name!
            : String(localized: "routes.imported")
        return GPXImportService.ImportedRoute(name: resolvedName, coordinates: line)
    }
}
