import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let gpx = UTType("com.topografix.gpx")
        ?? UTType(filenameExtension: "gpx", conformingTo: .xml)
        ?? .xml
}

/// Resolves the name shown in the app for an imported route/waypoint/activity.
///
/// When the user imports a file picked from Files (or "Open with"), the filename
/// without extension is almost always more meaningful than the embedded GPX `<name>`
/// element (which is often a cryptic exporter-generated string). We therefore use
/// the filename as the primary source, falling back to the embedded name only when
/// no filename is supplied (e.g. drag-and-drop without URL context).
///
/// For multi-item files we keep names distinct with " 2", " 3", … suffixes, the
/// same convention iOS uses for duplicate filenames.
enum ImportedName {
    static func resolve(embedded: String, filename: String?, index: Int, total: Int) -> String {
        if let filename {
            let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return total > 1 ? "\(trimmed) \(index + 1)" : trimmed
            }
        }
        return embedded
    }
}

extension URL {
    /// Filename without path or extension, suitable for naming imported items.
    var importedItemName: String {
        deletingPathExtension().lastPathComponent
    }
}

enum GPXImportService {
    enum ImportError: LocalizedError {
        case fileTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let bytes):
                let mb = bytes / (1024 * 1024)
                return String(localized: "gpx.fileTooLarge \(mb)")
            }
        }
    }

    private static let maxFileSize = 50 * 1024 * 1024 // 50 MB

    // Per-feature point cap. Real recordings rarely exceed a few thousand points
    // per track. A pathologically dense file (or a malicious one) could otherwise
    // generate millions of points in memory even within the 50 MB file cap. Any
    // points beyond this limit are dropped silently during parsing.
    static let maxPointsPerFeature = 50_000

    struct ImportedWaypoint: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        let elevation: Double?
        let category: String?
        /// Tråkke-spesifikke felt fra `<trakke:color>` og `<trakke:icon>` i
        /// `<extensions>`. Bevares ved round-trip eksport/import.
        var color: String? = nil
        var icon: String? = nil
        var details: String? = nil
    }

    struct ImportedRoute: Sendable {
        let name: String
        /// `[longitude, latitude]` when the source file has no per-point
        /// elevation, or `[longitude, latitude, elevation]` when it does.
        /// We persist the 3rd element so the elevation profile can render
        /// without a DEM round-trip – which is essential offline and avoids
        /// throwing away data the user already imported.
        let coordinates: [[Double]]
        /// Kategori fra `<type>` på `<trk>`-nivå. Bevares ved import.
        var category: String? = nil
        /// Tråkke-spesifikke felt fra `<extensions>` på trk-nivå.
        var color: String? = nil
        var difficulty: String? = nil
    }

    /// Activity tracks include per-point elevation and timestamps when present.
    /// Track points use the same 4-tuple layout as `Activity.trackPoints`:
    /// `[longitude, latitude, elevation, timestamp]`. Missing elevation defaults
    /// to 0; missing timestamp defaults to the activity's startedAt.
    struct ImportedActivity: Sendable {
        let name: String
        let trackPoints: [[Double]]
        let startedAt: Date
        /// Kategori fra `<type>` på `<trk>`-nivå. Bevares ved import.
        var category: String? = nil
    }

    static func parseWaypoints(from url: URL) throws -> [ImportedWaypoint] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard data.count <= maxFileSize else {
            throw ImportError.fileTooLarge(data.count)
        }
        let parser = GPXWaypointParser()
        return try parser.parse(data: data)
    }

    static func parseRoutes(from url: URL) throws -> [ImportedRoute] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard data.count <= maxFileSize else {
            throw ImportError.fileTooLarge(data.count)
        }
        let parser = GPXRouteParser()
        return try parser.parse(data: data)
    }

    static func parseActivities(from url: URL) throws -> [ImportedActivity] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard data.count <= maxFileSize else {
            throw ImportError.fileTooLarge(data.count)
        }
        let parser = GPXActivityParser()
        return try parser.parse(data: data)
    }
}

// MARK: - XML Parser

// MARK: - Waypoint Parser

private class GPXWaypointParser: NSObject, XMLParserDelegate {
    private var waypoints: [GPXImportService.ImportedWaypoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentName: String?
    private var currentDesc: String?
    private var currentElevation: Double?
    private var currentType: String?
    private var currentColor: String?
    private var currentIcon: String?
    private var currentText = ""
    private var insideWpt = false
    private var insideExtensions = false

    func parse(data: Data) throws -> [GPXImportService.ImportedWaypoint] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        if !parser.parse(), let error = parser.parserError { throw error }
        return waypoints
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        if name == "wpt" {
            insideWpt = true
            currentLat = Double(attributes["lat"] ?? "")
            currentLon = Double(attributes["lon"] ?? "")
            currentName = nil
            currentDesc = nil
            currentElevation = nil
            currentType = nil
            currentColor = nil
            currentIcon = nil
        } else if name == "extensions", insideWpt {
            insideExtensions = true
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard insideWpt else { return }
        let name = elementName.lowercased()
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "name" where !insideExtensions:
            currentName = trimmed
        case "desc" where !insideExtensions:
            currentDesc = trimmed.isEmpty ? nil : trimmed
        case "ele" where !insideExtensions:
            currentElevation = Double(trimmed)
        case "type" where !insideExtensions:
            currentType = trimmed.isEmpty ? nil : trimmed
        case "trakke:color":
            if insideExtensions, !trimmed.isEmpty { currentColor = trimmed }
        case "trakke:icon":
            if insideExtensions, !trimmed.isEmpty { currentIcon = trimmed }
        case "extensions":
            insideExtensions = false
        case "wpt":
            if let lat = currentLat, let lon = currentLon,
               lat.isFinite, lon.isFinite,
               (-90...90).contains(lat), (-180...180).contains(lon) {
                var wp = GPXImportService.ImportedWaypoint(
                    name: currentName ?? String(localized: "waypoints.new"),
                    latitude: lat,
                    longitude: lon,
                    elevation: currentElevation,
                    category: currentType,
                    color: currentColor,
                    icon: currentIcon
                )
                wp.details = currentDesc
                waypoints.append(wp)
            }
            insideWpt = false
            insideExtensions = false
        default:
            break
        }
    }
}

// MARK: - Route Parser

private class GPXRouteParser: NSObject, XMLParserDelegate {
    private var routes: [GPXImportService.ImportedRoute] = []
    private var currentName: String?
    private var currentCoords: [[Double]] = []
    private var currentCategory: String?
    private var currentColor: String?
    private var currentDifficulty: String?
    private var currentText = ""
    private var insideTrk = false
    private var insideTrkSeg = false
    private var insideRte = false
    private var insideExtensions = false
    /// Track which point in `currentCoords` we last touched, so a trailing
    /// `<ele>` element can attach to it. Set when a trkpt/rtept is appended.
    private var pendingPointIndex: Int?
    /// Whether the current route has any per-point elevation. If not, we
    /// emit 2-tuples [lon, lat]; if yes, we emit 3-tuples [lon, lat, ele].
    /// Mixed files: missing-ele points get the previous neighbor's elevation
    /// or fall back to the file's average rather than 0, which would create
    /// false drops in the profile.
    private var currentHasElevation = false

    func parse(data: Data) throws -> [GPXImportService.ImportedRoute] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        if !parser.parse(), let error = parser.parserError { throw error }
        return routes
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        switch name {
        case "trk":
            insideTrk = true
            currentName = nil
            currentCoords = []
            currentCategory = nil
            currentColor = nil
            currentDifficulty = nil
            currentHasElevation = false
            pendingPointIndex = nil
        case "trkseg":
            insideTrkSeg = true
        case "trkpt":
            if insideTrkSeg,
               currentCoords.count < GPXImportService.maxPointsPerFeature,
               let lat = Double(attributes["lat"] ?? ""),
               let lon = Double(attributes["lon"] ?? ""),
               lat.isFinite, lon.isFinite,
               (-90...90).contains(lat), (-180...180).contains(lon) {
                currentCoords.append([lon, lat])
                pendingPointIndex = currentCoords.count - 1
            }
        case "rte":
            insideRte = true
            currentName = nil
            currentCoords = []
            currentCategory = nil
            currentColor = nil
            currentDifficulty = nil
            currentHasElevation = false
            pendingPointIndex = nil
        case "rtept":
            if insideRte,
               currentCoords.count < GPXImportService.maxPointsPerFeature,
               let lat = Double(attributes["lat"] ?? ""),
               let lon = Double(attributes["lon"] ?? ""),
               lat.isFinite, lon.isFinite,
               (-90...90).contains(lat), (-180...180).contains(lon) {
                currentCoords.append([lon, lat])
                pendingPointIndex = currentCoords.count - 1
            }
        case "extensions":
            // Only treat as trk-level extensions when not inside a trkpt/seg.
            if (insideTrk && !insideTrkSeg) || insideRte {
                insideExtensions = true
            }
        default:
            break
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let name = elementName.lowercased()
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "name":
            if (insideTrk && !insideTrkSeg) || insideRte {
                currentName = trimmed
            }
        case "type":
            // Kategori på trk-/rte-nivå (ikke inni trkpt eller extensions).
            if ((insideTrk && !insideTrkSeg) || insideRte), !insideExtensions {
                currentCategory = trimmed.isEmpty ? nil : trimmed
            }
        case "trakke:color":
            if insideExtensions, !trimmed.isEmpty { currentColor = trimmed }
        case "trakke:difficulty":
            if insideExtensions, !trimmed.isEmpty { currentDifficulty = trimmed }
        case "ele":
            if let idx = pendingPointIndex,
               idx < currentCoords.count,
               let ele = Double(trimmed),
               ele.isFinite {
                // Replace [lon, lat] with [lon, lat, ele] for this point.
                var point = currentCoords[idx]
                if point.count >= 2 {
                    point.append(ele)
                    currentCoords[idx] = point
                    currentHasElevation = true
                }
            }
        case "extensions":
            insideExtensions = false
        case "trkpt", "rtept":
            // Done with this point – no further <ele> belongs to it.
            pendingPointIndex = nil
        case "trkseg":
            insideTrkSeg = false
        case "trk":
            emitCurrentRoute()
            insideTrk = false
            insideExtensions = false
        case "rte":
            emitCurrentRoute()
            insideRte = false
            insideExtensions = false
        default:
            break
        }
    }

    /// Emit the accumulated track/route as an ImportedRoute. When the file
    /// has elevation on some but not all points, fill the gaps with the
    /// nearest preceding elevation (or 0 only if no point ever had one)
    /// so the profile chart doesn't crash to zero between samples.
    private func emitCurrentRoute() {
        guard currentCoords.count >= 2 else { return }
        var coords = currentCoords
        if currentHasElevation {
            var lastEle: Double = 0
            var sawEle = false
            for i in 0..<coords.count {
                if coords[i].count >= 3 {
                    lastEle = coords[i][2]
                    sawEle = true
                } else if sawEle {
                    coords[i].append(lastEle)
                }
            }
            // Back-fill leading points that had no elevation seen yet.
            for i in 0..<coords.count {
                if coords[i].count < 3 {
                    coords[i].append(lastEle)
                }
            }
        }
        routes.append(GPXImportService.ImportedRoute(
            name: currentName ?? String(localized: "routes.imported"),
            coordinates: coords,
            category: currentCategory,
            color: currentColor,
            difficulty: currentDifficulty
        ))
    }
}

// MARK: - Activity Parser

/// Parses `<trk>` elements with full elevation and timestamp data, producing
/// 4-tuple track points compatible with `Activity.trackPoints`. Tracks without
/// any timestamps are still imported, with each point's timestamp falling back
/// to the track's startedAt (so we can still display them in the activity list).
private class GPXActivityParser: NSObject, XMLParserDelegate {
    private var activities: [GPXImportService.ImportedActivity] = []
    private var currentName: String?
    private var currentCategory: String?
    private var currentPoints: [[Double]] = []
    private var currentStartedAt: Date?
    private var currentText = ""
    private var insideTrk = false
    private var insideTrkSeg = false
    private var insideTrkPt = false
    private var insideExtensions = false
    private var pendingLat: Double?
    private var pendingLon: Double?
    private var pendingEle: Double?
    private var pendingTime: Date?

    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parse(data: Data) throws -> [GPXImportService.ImportedActivity] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        if !parser.parse(), let error = parser.parserError { throw error }
        return activities
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        switch name {
        case "trk":
            insideTrk = true
            currentName = nil
            currentCategory = nil
            currentPoints = []
            currentStartedAt = nil
        case "trkseg":
            insideTrkSeg = true
        case "trkpt":
            if insideTrkSeg,
               currentPoints.count < GPXImportService.maxPointsPerFeature,
               let lat = Double(attributes["lat"] ?? ""),
               let lon = Double(attributes["lon"] ?? ""),
               lat.isFinite, lon.isFinite,
               (-90...90).contains(lat), (-180...180).contains(lon) {
                insideTrkPt = true
                pendingLat = lat
                pendingLon = lon
                pendingEle = nil
                pendingTime = nil
            }
        case "extensions":
            // Only treat as trk-level extensions when not inside a trkpt/seg.
            if insideTrk && !insideTrkSeg && !insideTrkPt {
                insideExtensions = true
            }
        default:
            break
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let name = elementName.lowercased()
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "name":
            if insideTrk && !insideTrkSeg {
                currentName = trimmed
            }
        case "type":
            // Kategori på trk-nivå (ikke inni trkpt eller extensions).
            if insideTrk && !insideTrkSeg && !insideTrkPt && !insideExtensions {
                currentCategory = trimmed.isEmpty ? nil : trimmed
            }
        case "ele":
            if insideTrkPt, let ele = Double(trimmed), ele.isFinite {
                pendingEle = ele
            }
        case "time":
            if insideTrkPt {
                pendingTime = iso8601Formatter.date(from: trimmed)
                    ?? iso8601FormatterNoFraction.date(from: trimmed)
            }
        case "extensions":
            insideExtensions = false
        case "trkpt":
            if let lat = pendingLat, let lon = pendingLon {
                if currentStartedAt == nil, let t = pendingTime {
                    currentStartedAt = t
                }
                let timestamp = pendingTime?.timeIntervalSince1970
                    ?? currentStartedAt?.timeIntervalSince1970
                    ?? Date.now.timeIntervalSince1970
                currentPoints.append([lon, lat, pendingEle ?? 0, timestamp])
            }
            insideTrkPt = false
            pendingLat = nil
            pendingLon = nil
            pendingEle = nil
            pendingTime = nil
        case "trkseg":
            insideTrkSeg = false
        case "trk":
            // Only treat this <trk> as an activity if the timestamps are actually
            // varied – i.e. someone recorded GPS points over time. UT.no, Komoot
            // and similar planning tools export planned routes with placeholder
            // timestamps where every <trkpt> has the same time. Those are routes,
            // not activities, and `parseRoutes` will pick them up instead.
            if currentPoints.count >= 2, hasMonotonicTimestamps(currentPoints) {
                activities.append(GPXImportService.ImportedActivity(
                    name: currentName ?? String(localized: "activity.imported"),
                    trackPoints: currentPoints,
                    startedAt: currentStartedAt ?? Date.now,
                    category: currentCategory
                ))
            }
            insideTrk = false
            insideExtensions = false
        default:
            break
        }
    }

    private func hasMonotonicTimestamps(_ points: [[Double]]) -> Bool {
        guard points.count >= 2 else { return false }
        let timestamps = points.compactMap { $0.count >= 4 ? $0[3] : nil }
        guard timestamps.count >= 2 else { return false }
        guard let first = timestamps.first, let last = timestamps.last else { return false }
        // Real recordings span at least a few seconds. A planned-route export
        // with placeholder times produces zero or tiny duration.
        return (last - first) >= 1.0
    }
}
