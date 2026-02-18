import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let gpx = UTType(filenameExtension: "gpx", conformingTo: .xml)!
}

enum GPXImportService {
    struct ImportedWaypoint: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        let elevation: Double?
        let category: String?
    }

    static func parseWaypoints(from url: URL) throws -> [ImportedWaypoint] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let parser = GPXWaypointParser()
        return parser.parse(data: data)
    }
}

// MARK: - XML Parser

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
            if let lat = currentLat, let lon = currentLon {
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
