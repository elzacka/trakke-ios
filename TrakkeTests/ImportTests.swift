import Testing
import Foundation
@testable import Trakke

// MARK: - GeoJSON Import Tests

@Test func geoJSONImportPointFeature() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [10.7522, 59.9139, 12.5] },
      "properties": { "name": "Oslo S" }
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.waypoints.count == 1)
    #expect(result.routes.isEmpty)
    #expect(result.activities.isEmpty)
    let wp = result.waypoints[0]
    #expect(wp.name == "Oslo S")
    #expect(abs(wp.latitude - 59.9139) < 0.0001)
    #expect(abs(wp.longitude - 10.7522) < 0.0001)
    #expect(wp.elevation == 12.5)
}

@Test func geoJSONImportFeatureCollection() throws {
    let json = """
    {
      "type": "FeatureCollection",
      "features": [
        { "type": "Feature", "geometry": { "type": "Point", "coordinates": [10.0, 60.0] }, "properties": { "name": "A" } },
        { "type": "Feature", "geometry": { "type": "Point", "coordinates": [11.0, 61.0] }, "properties": { "name": "B" } }
      ]
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.waypoints.count == 2)
    #expect(result.waypoints[0].name == "A")
    #expect(result.waypoints[1].name == "B")
}

@Test func geoJSONImportBareGeometry() throws {
    let json = """
    { "type": "Point", "coordinates": [10.7522, 59.9139] }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.waypoints.count == 1)
    #expect(abs(result.waypoints[0].latitude - 59.9139) < 0.0001)
}

@Test func geoJSONImportLineStringAsRoute() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[10.0, 59.0], [10.1, 59.1], [10.2, 59.2]]
      },
      "properties": { "name": "Min tur" }
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.routes.count == 1)
    #expect(result.activities.isEmpty)
    #expect(result.routes[0].name == "Min tur")
    #expect(result.routes[0].coordinates.count == 3)
}

@Test func geoJSONImportLineStringWithTimesAsActivity() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[10.0, 59.0, 100], [10.001, 59.001, 105], [10.002, 59.002, 110]]
      },
      "properties": {
        "name": "Morgenløp",
        "coordinateProperties": {
          "times": ["2026-05-19T08:00:00Z", "2026-05-19T08:00:30Z", "2026-05-19T08:01:00Z"]
        }
      }
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.activities.count == 1)
    #expect(result.routes.isEmpty)
    #expect(result.activities[0].name == "Morgenløp")
    #expect(result.activities[0].trackPoints.count == 3)
    #expect(result.activities[0].trackPoints[0][2] == 100)
}

@Test func geoJSONImportTimesIdenticalFallsBackToRoute() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[10.0, 59.0], [10.1, 59.1]]
      },
      "properties": {
        "coordinateProperties": {
          "times": ["2026-05-19T08:00:00Z", "2026-05-19T08:00:00Z"]
        }
      }
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.activities.isEmpty)
    #expect(result.routes.count == 1)
}

@Test func geoJSONImportPolygonAsClosedRoute() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[10.0, 59.0], [10.1, 59.0], [10.1, 59.1]]]
      },
      "properties": { "name": "Område" }
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.routes.count == 1)
    let coords = result.routes[0].coordinates
    #expect(coords.count == 4, "Polygon should be closed (4 points)")
    #expect(coords.first?[0] == coords.last?[0])
    #expect(coords.first?[1] == coords.last?[1])
}

@Test func geoJSONImportMultiPoint() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": {
        "type": "MultiPoint",
        "coordinates": [[10.0, 59.0], [11.0, 60.0], [12.0, 61.0]]
      },
      "properties": {}
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.waypoints.count == 3)
}

@Test func geoJSONImportGeometryCollection() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": {
        "type": "GeometryCollection",
        "geometries": [
          { "type": "Point", "coordinates": [10.0, 59.0] },
          { "type": "LineString", "coordinates": [[10.0, 59.0], [10.1, 59.1]] }
        ]
      },
      "properties": {}
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.waypoints.count == 1)
    #expect(result.routes.count == 1)
}

@Test func geoJSONImportInvalidJSONThrows() {
    let bad = "not json {{{".data(using: .utf8)!
    #expect(throws: GeoJSONImportService.ImportError.self) {
        _ = try GeoJSONImportService.parse(data: bad)
    }
}

@Test func geoJSONImportMissingTypeThrows() {
    let json = """
    { "features": [] }
    """
    #expect(throws: GeoJSONImportService.ImportError.self) {
        _ = try GeoJSONImportService.parse(data: Data(json.utf8))
    }
}

@Test func geoJSONImportRejectsOutOfRangeCoordinates() throws {
    let json = """
    {
      "type": "FeatureCollection",
      "features": [
        { "type": "Feature", "geometry": { "type": "Point", "coordinates": [200.0, 95.0] }, "properties": {} },
        { "type": "Feature", "geometry": { "type": "Point", "coordinates": [10.0, 60.0] }, "properties": {} }
      ]
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.waypoints.count == 1, "Out-of-range coordinate must be dropped")
    #expect(abs(result.waypoints[0].latitude - 60.0) < 0.0001)
}

@Test func geoJSONImportRejectsNonFiniteCoordinates() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": { "type": "LineString", "coordinates": [[10.0, 59.0], [10.1, 59.1]] },
      "properties": {}
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.routes.count == 1)
}

@Test func geoJSONImportRoutePreservesElevation() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": { "type": "LineString", "coordinates": [[10.0, 59.0, 100], [10.1, 59.1, 200]] },
      "properties": {}
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.routes.count == 1)
    #expect(result.routes[0].coordinates[0].count == 3)
    #expect(result.routes[0].coordinates[0][2] == 100)
    #expect(result.routes[0].coordinates[1][2] == 200)
}

@Test func geoJSONImportRouteWithTooFewPointsIsDropped() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": { "type": "LineString", "coordinates": [[10.0, 59.0]] },
      "properties": {}
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.routes.isEmpty)
}

@Test func geoJSONImportNorwegianCharacters() throws {
    let json = """
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [18.9560, 69.6496] },
      "properties": { "name": "Tromsø Fjellheis", "category": "Utsiktspunkt med æ, ø og å" }
    }
    """
    let result = try GeoJSONImportService.parse(data: Data(json.utf8))
    #expect(result.waypoints.count == 1)
    #expect(result.waypoints[0].name == "Tromsø Fjellheis")
    #expect(result.waypoints[0].category == "Utsiktspunkt med æ, ø og å")
}

// MARK: - GPX Hardening Tests

@Test func gpxImportRejectsOutOfRangeLatitude() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <wpt lat="95.0" lon="10.0"><name>Off planet</name></wpt>
      <wpt lat="59.9" lon="10.7"><name>Oslo</name></wpt>
    </gpx>
    """
    let url = try writeImportTempFile(gpx, name: "out_of_range.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)
    #expect(waypoints.count == 1)
    #expect(waypoints[0].name == "Oslo")
}

@Test func gpxImportRejectsOutOfRangeLongitude() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <wpt lat="59.9" lon="200.0"><name>Off planet</name></wpt>
      <wpt lat="59.9" lon="10.7"><name>Oslo</name></wpt>
    </gpx>
    """
    let url = try writeImportTempFile(gpx, name: "out_of_range_lon.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)
    #expect(waypoints.count == 1)
    #expect(waypoints[0].name == "Oslo")
}

@Test func gpxImportFileTooLargeThrows() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("oversized.gpx")
    let oversized = String(repeating: "x", count: 51 * 1024 * 1024)
    try oversized.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: GPXImportService.ImportError.self) {
        _ = try GPXImportService.parseWaypoints(from: url)
    }
}

@Test func gpxImportCapsPointsPerFeature() throws {
    var trkpts = ""
    let pointCount = GPXImportService.maxPointsPerFeature + 100
    for i in 0..<pointCount {
        let lat = 59.0 + Double(i) * 0.00001
        trkpts += "<trkpt lat=\"\(lat)\" lon=\"10.0\"></trkpt>\n"
    }
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk><name>Tett</name><trkseg>
        \(trkpts)
      </trkseg></trk>
    </gpx>
    """
    let url = try writeImportTempFile(gpx, name: "many_points.gpx")
    let routes = try GPXImportService.parseRoutes(from: url)
    #expect(routes.count == 1)
    #expect(routes[0].coordinates.count == GPXImportService.maxPointsPerFeature)
}

// MARK: - GPX Activity Parser Tests

@Test func gpxImportActivityWithMonotonicTimestamps() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk><name>Morgenløp</name><trkseg>
        <trkpt lat="59.9" lon="10.7"><ele>10</ele><time>2026-05-19T08:00:00Z</time></trkpt>
        <trkpt lat="59.91" lon="10.71"><ele>12</ele><time>2026-05-19T08:01:00Z</time></trkpt>
        <trkpt lat="59.92" lon="10.72"><ele>14</ele><time>2026-05-19T08:02:00Z</time></trkpt>
      </trkseg></trk>
    </gpx>
    """
    let url = try writeImportTempFile(gpx, name: "activity.gpx")
    let activities = try GPXImportService.parseActivities(from: url)
    #expect(activities.count == 1)
    #expect(activities[0].name == "Morgenløp")
    #expect(activities[0].trackPoints.count == 3)
    let firstPoint = activities[0].trackPoints[0]
    #expect(firstPoint.count == 4, "[lon, lat, ele, timestamp]")
    #expect(firstPoint[2] == 10)
}

@Test func gpxImportPlannedRouteNotImportedAsActivity() throws {
    // All timestamps identical → planning-tool export, not a recording
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk><name>Planlagt</name><trkseg>
        <trkpt lat="59.9" lon="10.7"><time>2026-05-19T08:00:00Z</time></trkpt>
        <trkpt lat="59.91" lon="10.71"><time>2026-05-19T08:00:00Z</time></trkpt>
      </trkseg></trk>
    </gpx>
    """
    let url = try writeImportTempFile(gpx, name: "planned.gpx")
    let activities = try GPXImportService.parseActivities(from: url)
    #expect(activities.isEmpty)
}

@Test func gpxImportActivityFractionalSecondsTimestamps() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk><name>Med brøkdeler</name><trkseg>
        <trkpt lat="60.0" lon="10.0"><time>2026-05-19T08:00:00.123Z</time></trkpt>
        <trkpt lat="60.001" lon="10.001"><time>2026-05-19T08:00:01.456Z</time></trkpt>
        <trkpt lat="60.002" lon="10.002"><time>2026-05-19T08:00:02.789Z</time></trkpt>
      </trkseg></trk>
    </gpx>
    """
    let url = try writeImportTempFile(gpx, name: "fractional.gpx")
    let activities = try GPXImportService.parseActivities(from: url)
    #expect(activities.count == 1)
}

@Test func gpxRouteImportWithElevationProducesThreeTuples() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk><name>Med høyde</name><trkseg>
        <trkpt lat="61.5" lon="8.8"><ele>1000</ele></trkpt>
        <trkpt lat="61.501" lon="8.801"><ele>1010</ele></trkpt>
        <trkpt lat="61.502" lon="8.802"><ele>1020</ele></trkpt>
      </trkseg></trk>
    </gpx>
    """
    let url = try writeImportTempFile(gpx, name: "elevation.gpx")
    let routes = try GPXImportService.parseRoutes(from: url)
    #expect(routes.count == 1)
    #expect(routes[0].coordinates.allSatisfy { $0.count == 3 })
    #expect(routes[0].coordinates[0][2] == 1000)
}

// MARK: - ImportedName Tests

@Test func importedNameFromFilenameSingle() {
    let name = ImportedName.resolve(embedded: "GPX-12345", filename: "Min Tur", index: 0, total: 1)
    #expect(name == "Min Tur")
}

@Test func importedNameFromFilenameMultiple() {
    let n1 = ImportedName.resolve(embedded: "X", filename: "Tur", index: 0, total: 3)
    let n2 = ImportedName.resolve(embedded: "X", filename: "Tur", index: 1, total: 3)
    #expect(n1 == "Tur 1")
    #expect(n2 == "Tur 2")
}

@Test func importedNameFallsBackToEmbedded() {
    let name = ImportedName.resolve(embedded: "Embedded navn", filename: nil, index: 0, total: 1)
    #expect(name == "Embedded navn")
}

@Test func importedNameWhitespaceFilenameFallsBack() {
    let name = ImportedName.resolve(embedded: "Embedded", filename: "   ", index: 0, total: 1)
    #expect(name == "Embedded")
}

// MARK: - Helpers

private func writeImportTempFile(_ content: String, name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}
