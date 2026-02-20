import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let gpx = UTType("com.topografix.gpx")
        ?? UTType(filenameExtension: "gpx", conformingTo: .xml)
        ?? .xml
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

    struct ImportedWaypoint: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        let elevation: Double?
        let category: String?
    }

    struct ImportedRoute: Sendable {
        let name: String
        let coordinates: [[Double]] // [longitude, latitude]
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
        return parser.parse(data: data)
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
        return parser.parse(data: data)
    }
}

// MARK: - XML Parser

// MARK: - Waypoint Parser

private class GPXWaypointParser: NSObject, XMLParserDelegate {
    private var waypoints: [GPXImportService.ImportedWaypoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentName: String?
    private var currentElevation: Double?
    private var currentType: String?
    private var currentText = ""
    private var insideWpt = false

    func parse(data: Data) -> [GPXImportService.ImportedWaypoint] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        parser.parse()
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
            currentElevation = nil
            currentType = nil
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
        case "name":
            currentName = trimmed
        case "ele":
            currentElevation = Double(trimmed)
        case "type":
            currentType = trimmed.isEmpty ? nil : trimmed
        case "wpt":
            if let lat = currentLat, let lon = currentLon,
               lat.isFinite, lon.isFinite {
                let wp = GPXImportService.ImportedWaypoint(
                    name: currentName ?? String(localized: "waypoints.new"),
                    latitude: lat,
                    longitude: lon,
                    elevation: currentElevation,
                    category: currentType
                )
                waypoints.append(wp)
            }
            insideWpt = false
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
    private var currentText = ""
    private var insideTrk = false
    private var insideTrkSeg = false
    private var insideRte = false

    func parse(data: Data) -> [GPXImportService.ImportedRoute] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        parser.parse()
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
        case "trkseg":
            insideTrkSeg = true
        case "trkpt":
            if insideTrkSeg,
               let lat = Double(attributes["lat"] ?? ""),
               let lon = Double(attributes["lon"] ?? ""),
               lat.isFinite, lon.isFinite {
                currentCoords.append([lon, lat])
            }
        case "rte":
            insideRte = true
            currentName = nil
            currentCoords = []
        case "rtept":
            if insideRte,
               let lat = Double(attributes["lat"] ?? ""),
               let lon = Double(attributes["lon"] ?? ""),
               lat.isFinite, lon.isFinite {
                currentCoords.append([lon, lat])
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
        switch name {
        case "name":
            if (insideTrk && !insideTrkSeg) || insideRte {
                currentName = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case "trkseg":
            insideTrkSeg = false
        case "trk":
            if currentCoords.count >= 2 {
                routes.append(GPXImportService.ImportedRoute(
                    name: currentName ?? String(localized: "routes.imported"),
                    coordinates: currentCoords
                ))
            }
            insideTrk = false
        case "rte":
            if currentCoords.count >= 2 {
                routes.append(GPXImportService.ImportedRoute(
                    name: currentName ?? String(localized: "routes.imported"),
                    coordinates: currentCoords
                ))
            }
            insideRte = false
        default:
            break
        }
    }
}
