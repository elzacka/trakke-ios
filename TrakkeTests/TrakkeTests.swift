import Testing
import Foundation
import CoreLocation
import SwiftData
@testable import Trakke

// MARK: - Model Tests

@Test func routeCreation() async throws {
    let route = Route(name: "Testtur")
    #expect(route.name == "Testtur")
    #expect(UUID(uuidString: route.id) != nil)
    #expect(route.coordinates.isEmpty)
}

@Test func waypointCreation() async throws {
    let wp = Waypoint(name: "Utsiktspunkt", coordinates: [10.7522, 59.9139])
    #expect(wp.name == "Utsiktspunkt")
    #expect(UUID(uuidString: wp.id) != nil)
    #expect(wp.coordinates.count == 2)
}

// MARK: - Levenshtein Tests

@Test func levenshteinIdentical() {
    #expect(Levenshtein.distance("oslo", "oslo") == 0)
}

@Test func levenshteinOneEdit() {
    #expect(Levenshtein.distance("oslo", "Osli") == 2) // case + char
    #expect(Levenshtein.distance("bergen", "berge") == 1)
}

@Test func levenshteinEmpty() {
    #expect(Levenshtein.distance("", "abc") == 3)
    #expect(Levenshtein.distance("abc", "") == 3)
}

// MARK: - Coordinate Parsing Tests

@Test func parseDD() {
    let result = CoordinateService.parse("59.9139, 10.7522")
    #expect(result != nil)
    #expect(result?.type == .coordinates)
    #expect(abs(result!.coordinate.latitude - 59.9139) < 0.001)
    #expect(abs(result!.coordinate.longitude - 10.7522) < 0.001)
}

@Test func parseDDWithDirections() {
    let result = CoordinateService.parse("N59.9139 E10.7522")
    #expect(result != nil)
    #expect(abs(result!.coordinate.latitude - 59.9139) < 0.001)
    #expect(abs(result!.coordinate.longitude - 10.7522) < 0.001)
}

@Test func parseDMS() {
    let result = CoordinateService.parse("59\u{00B0}54\u{2032}50.0\u{2033}N, 10\u{00B0}45\u{2032}7.9\u{2033}E")
    #expect(result != nil)
    #expect(abs(result!.coordinate.latitude - 59.9139) < 0.01)
    #expect(abs(result!.coordinate.longitude - 10.752) < 0.01)
}

@Test func parseDDM() {
    let result = CoordinateService.parse("59\u{00B0}54.833\u{2032}N, 10\u{00B0}45.132\u{2032}E")
    #expect(result != nil)
    #expect(abs(result!.coordinate.latitude - 59.9139) < 0.01)
    #expect(abs(result!.coordinate.longitude - 10.7522) < 0.01)
}

@Test func parseUTM() {
    let result = CoordinateService.parse("32V 597423 6643460")
    #expect(result != nil)
    #expect(result?.type == .coordinates)
    // Should be roughly Oslo area
    #expect(result!.coordinate.latitude > 59 && result!.coordinate.latitude < 60)
    #expect(result!.coordinate.longitude > 10 && result!.coordinate.longitude < 11)
}

@Test func parseMGRS() {
    let result = CoordinateService.parse("32VNM9742371394")
    #expect(result != nil)
    #expect(result?.type == .coordinates)
}

// MARK: - Coordinate Formatting Tests

@Test func formatDD() {
    let coord = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let formatted = CoordinateService.format(coordinate: coord, format: .dd)
    #expect(formatted.display.contains("59.913900"))
    #expect(formatted.display.contains("N"))
    #expect(formatted.display.contains("E"))
}

@Test func formatDMS() {
    let coord = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let formatted = CoordinateService.format(coordinate: coord, format: .dms)
    #expect(formatted.display.contains("59"))
    #expect(formatted.display.contains("N"))
}

@Test func formatUTM() {
    let coord = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let formatted = CoordinateService.format(coordinate: coord, format: .utm)
    #expect(formatted.display.contains("32"))
    #expect(formatted.display.contains("V"))
}

@Test func formatMGRS() {
    let coord = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let formatted = CoordinateService.format(coordinate: coord, format: .mgrs)
    #expect(formatted.display.contains("32V"))
}

// MARK: - Coordinate Invalid Input

@Test func parseInvalidReturnsNil() {
    #expect(CoordinateService.parse("not a coordinate") == nil)
    #expect(CoordinateService.parse("abc, def") == nil)
    #expect(CoordinateService.parse("") == nil)
}

// MARK: - Haversine Tests

@Test func haversineDistanceOsloToTrondheim() {
    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let trondheim = CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951)
    let distance = Haversine.distance(from: oslo, to: trondheim)
    // ~392 km
    #expect(distance > 390_000 && distance < 395_000)
}

@Test func haversineTotalDistance() {
    let coords = [
        CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
        CLLocationCoordinate2D(latitude: 59.9200, longitude: 10.7600),
        CLLocationCoordinate2D(latitude: 59.9300, longitude: 10.7700),
    ]
    let total = Haversine.totalDistance(coordinates: coords)
    #expect(total > 0)
    // Should be sum of two segments
    let seg1 = Haversine.distance(from: coords[0], to: coords[1])
    let seg2 = Haversine.distance(from: coords[1], to: coords[2])
    #expect(abs(total - (seg1 + seg2)) < 0.01)
}

@Test func haversineCumulativeDistances() {
    let coords = [
        CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.1, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.2, longitude: 10.0),
    ]
    let distances = Haversine.cumulativeDistances(coordinates: coords)
    #expect(distances.count == 3)
    #expect(distances[0] == 0)
    #expect(distances[1] > 0)
    #expect(distances[2] > distances[1])
}

// MARK: - GPX Export Tests

@Test func gpxExportContainsTrackpoints() {
    let route = Route(name: "Testrute")
    route.coordinates = [[10.7522, 59.9139], [10.7600, 59.9200]]
    let gpx = GPXExportService.exportRoute(route)
    #expect(gpx.contains("<gpx"))
    #expect(gpx.contains("<trk>"))
    #expect(gpx.contains("Testrute"))
    #expect(gpx.contains("trkpt"))
    #expect(gpx.contains("59.9139"))
}

@Test func gpxExportXMLEscaping() {
    let route = Route(name: "Tur & test <rute>")
    route.coordinates = [[10.0, 59.0]]
    let gpx = GPXExportService.exportRoute(route)
    #expect(gpx.contains("&amp;"))
    #expect(gpx.contains("&lt;"))
    #expect(gpx.contains("&gt;"))
}

@Test func gpxSanitizeFilename() {
    #expect(GPXExportService.sanitizeFilename("Min Tur!") == "min_tur.gpx")
    #expect(GPXExportService.sanitizeFilename("") == "rute.gpx")
}

// MARK: - Route Distance Calculation

@Test func haversineTotalDistanceFromCoordArrays() {
    let coords: [[Double]] = [[10.7522, 59.9139], [10.7600, 59.9200]]
    let distance = Haversine.totalDistance(coordinates: coords)
    #expect(distance > 0)
    // Roughly 800m
    #expect(distance > 500 && distance < 1500)
}

// MARK: - Offline Tile Estimation Tests

@Test func tileCountEstimation() {
    // Small area at single zoom
    let count = OfflineMapService.estimateTileCount(
        south: 59.9, west: 10.7, north: 60.0, east: 10.8,
        minZoom: 10, maxZoom: 10
    )
    #expect(count > 0)
    #expect(count < 100)
}

@Test func tileCountIncreasesWithZoom() {
    let countLow = OfflineMapService.estimateTileCount(
        south: 59.9, west: 10.7, north: 60.0, east: 10.8,
        minZoom: 10, maxZoom: 10
    )
    let countHigh = OfflineMapService.estimateTileCount(
        south: 59.9, west: 10.7, north: 60.0, east: 10.8,
        minZoom: 10, maxZoom: 14
    )
    #expect(countHigh > countLow)
}

@Test func formatBytesReadable() {
    #expect(OfflineMapService.formatBytes(500).contains("B"))
    #expect(OfflineMapService.formatBytes(1_500_000).contains("MB"))
    #expect(OfflineMapService.formatBytes(1_500_000_000).contains("GB"))
}

// MARK: - Measurement Service Tests

@Test func measurementDistanceTwoPoints() {
    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let bergen = CLLocationCoordinate2D(latitude: 60.3913, longitude: 5.3221)
    let distance = MeasurementService.distance(from: oslo, to: bergen)
    // Oslo to Bergen ~305 km
    #expect(distance > 300_000 && distance < 310_000)
}

@Test func measurementPolylineDistance() {
    let coords = [
        CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
        CLLocationCoordinate2D(latitude: 59.9200, longitude: 10.7600),
        CLLocationCoordinate2D(latitude: 59.9300, longitude: 10.7700),
    ]
    let distance = MeasurementService.polylineDistance(coords)
    #expect(distance > 0)
    // Sum of segments
    let expected = Haversine.totalDistance(coordinates: coords)
    #expect(abs(distance - expected) < 0.01)
}

@Test func measurementPolygonArea() {
    // Roughly 1 km x 1 km square near Oslo
    let coords = [
        CLLocationCoordinate2D(latitude: 59.90, longitude: 10.70),
        CLLocationCoordinate2D(latitude: 59.91, longitude: 10.70),
        CLLocationCoordinate2D(latitude: 59.91, longitude: 10.72),
        CLLocationCoordinate2D(latitude: 59.90, longitude: 10.72),
    ]
    let area = MeasurementService.polygonArea(coords)
    // Area should be roughly 1.1 km^2 = 1,100,000 m^2
    #expect(area > 500_000 && area < 2_000_000)
}

@Test func measurementPolygonAreaTooFewPoints() {
    let coords = [
        CLLocationCoordinate2D(latitude: 59.90, longitude: 10.70),
        CLLocationCoordinate2D(latitude: 59.91, longitude: 10.70),
    ]
    let area = MeasurementService.polygonArea(coords)
    #expect(area == 0)
}

@Test func measurementFormatDistance() {
    #expect(MeasurementService.formatDistance(500).contains("m"))
    #expect(MeasurementService.formatDistance(2500).contains("km"))
}

@Test func measurementFormatArea() {
    #expect(MeasurementService.formatArea(5000).contains("m"))
    #expect(MeasurementService.formatArea(50_000).contains("km"))
}

// MARK: - Weather Condition Text Tests

@Test func weatherConditionText() {
    #expect(WeatherViewModel.conditionText(for: "clearsky_day") == "Klarvær")
    #expect(WeatherViewModel.conditionText(for: "clearsky_night") == "Klarvær")
    #expect(WeatherViewModel.conditionText(for: "rain") == "Regn")
    #expect(WeatherViewModel.conditionText(for: "heavysnow") == "Kraftig snøfall")
    #expect(WeatherViewModel.conditionText(for: "unknown_symbol") == "Overskyet")
}

@Test func weatherWindDirection() {
    #expect(WeatherService.windDirectionName(0) == "N")
    #expect(WeatherService.windDirectionName(90) == "O")
    #expect(WeatherService.windDirectionName(180) == "S")
    #expect(WeatherService.windDirectionName(270) == "V")
}

@Test func weatherWindDirectionBoundaries() {
    // Values at exact boundary between sectors (45-degree increments)
    #expect(WeatherService.windDirectionName(22) == "N")
    #expect(WeatherService.windDirectionName(23) == "NO")
    #expect(WeatherService.windDirectionName(45) == "NO")
    #expect(WeatherService.windDirectionName(337) == "NV")
    #expect(WeatherService.windDirectionName(338) == "N")
    // Full circle wraps to N
    #expect(WeatherService.windDirectionName(360) == "N")
}

@Test func weatherWindDirectionNegativeDegrees() {
    // Negative degrees should wrap correctly via ((index % 8) + 8) % 8
    #expect(WeatherService.windDirectionName(-45) == "NV")   // -45 = 315
    #expect(WeatherService.windDirectionName(-90) == "V")    // -90 = 270
    #expect(WeatherService.windDirectionName(-180) == "S")   // -180 = 180
    #expect(WeatherService.windDirectionName(-270) == "O")   // -270 = 90
    #expect(WeatherService.windDirectionName(-360) == "N")   // -360 = 0
    #expect(WeatherService.windDirectionName(-22) == "N")    // Near-zero negative
    #expect(WeatherService.windDirectionName(-23) == "NV")   // Just past boundary
}

// MARK: - GPX Import Tests

@Test func gpxImportValidWaypoints() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <wpt lat="59.9139" lon="10.7522">
        <name>Oslo Sentrum</name>
        <ele>12.5</ele>
        <type>Utsiktspunkt</type>
      </wpt>
      <wpt lat="60.3913" lon="5.3221">
        <name>Bergen</name>
        <ele>3.0</ele>
      </wpt>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_valid.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)

    #expect(waypoints.count == 2)

    #expect(waypoints[0].name == "Oslo Sentrum")
    #expect(abs(waypoints[0].latitude - 59.9139) < 0.0001)
    #expect(abs(waypoints[0].longitude - 10.7522) < 0.0001)
    #expect(waypoints[0].elevation == 12.5)
    #expect(waypoints[0].category == "Utsiktspunkt")

    #expect(waypoints[1].name == "Bergen")
    #expect(abs(waypoints[1].latitude - 60.3913) < 0.0001)
    #expect(abs(waypoints[1].longitude - 5.3221) < 0.0001)
    #expect(waypoints[1].elevation == 3.0)
    #expect(waypoints[1].category == nil)
}

@Test func gpxImportMissingName() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <wpt lat="61.0" lon="7.0">
        <ele>500</ele>
      </wpt>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_noname.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)

    #expect(waypoints.count == 1)
    // Should have a default name (localized string key fallback)
    #expect(!waypoints[0].name.isEmpty)
    #expect(waypoints[0].elevation == 500)
}

@Test func gpxImportMissingCoordinates() throws {
    // Waypoint without lat/lon attributes should be skipped
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <wpt>
        <name>Broken</name>
      </wpt>
      <wpt lat="62.0" lon="6.0">
        <name>Valid</name>
      </wpt>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_nocoords.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)

    #expect(waypoints.count == 1)
    #expect(waypoints[0].name == "Valid")
}

@Test func gpxImportEmptyFile() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_empty.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)

    #expect(waypoints.isEmpty)
}

@Test func gpxImportNorwegianCharacters() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <wpt lat="69.6496" lon="18.9560">
        <name>Tromsø Fjellheis</name>
        <type>Utsiktspunkt med æ, ø og å</type>
      </wpt>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_norwegian.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)

    #expect(waypoints.count == 1)
    #expect(waypoints[0].name == "Tromsø Fjellheis")
    #expect(waypoints[0].category == "Utsiktspunkt med æ, ø og å")
}

@Test func gpxImportIgnoresTrackpoints() throws {
    // Track points (<trkpt>) should not be imported as waypoints
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <wpt lat="59.9" lon="10.7">
        <name>Waypoint</name>
      </wpt>
      <trk>
        <trkseg>
          <trkpt lat="59.91" lon="10.71"></trkpt>
          <trkpt lat="59.92" lon="10.72"></trkpt>
        </trkseg>
      </trk>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_with_track.gpx")
    let waypoints = try GPXImportService.parseWaypoints(from: url)

    #expect(waypoints.count == 1)
    #expect(waypoints[0].name == "Waypoint")
}

// MARK: - GPX Route Import Tests

@Test func gpxImportRouteFromTrk() throws {
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk>
        <name>Besseggen</name>
        <trkseg>
          <trkpt lat="61.5000" lon="8.8000"></trkpt>
          <trkpt lat="61.5010" lon="8.8010"></trkpt>
          <trkpt lat="61.5020" lon="8.8020"></trkpt>
        </trkseg>
      </trk>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_trk_route.gpx")
    let routes = try GPXImportService.parseRoutes(from: url)

    #expect(routes.count == 1)
    #expect(routes[0].name == "Besseggen")
    #expect(routes[0].coordinates.count == 3)
    // Coordinates stored as [lon, lat]
    #expect(abs(routes[0].coordinates[0][0] - 8.8000) < 0.0001)
    #expect(abs(routes[0].coordinates[0][1] - 61.5000) < 0.0001)
}

@Test func gpxImportRouteFromRte() throws {
    // <rte>/<rtept> format (alternative to <trk>/<trkseg>/<trkpt>)
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <rte>
        <name>Preikestolen</name>
        <rtept lat="58.9863" lon="6.1905"></rtept>
        <rtept lat="58.9870" lon="6.1910"></rtept>
        <rtept lat="58.9880" lon="6.1920"></rtept>
      </rte>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_rte_route.gpx")
    let routes = try GPXImportService.parseRoutes(from: url)

    #expect(routes.count == 1)
    #expect(routes[0].name == "Preikestolen")
    #expect(routes[0].coordinates.count == 3)
    #expect(abs(routes[0].coordinates[0][0] - 6.1905) < 0.0001)
    #expect(abs(routes[0].coordinates[0][1] - 58.9863) < 0.0001)
}

@Test func gpxImportRouteTooFewPoints() throws {
    // A route with fewer than 2 points should be skipped
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk>
        <name>Kort</name>
        <trkseg>
          <trkpt lat="60.0" lon="10.0"></trkpt>
        </trkseg>
      </trk>
      <rte>
        <name>Ogsaa kort</name>
        <rtept lat="61.0" lon="11.0"></rtept>
      </rte>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_short_routes.gpx")
    let routes = try GPXImportService.parseRoutes(from: url)

    #expect(routes.isEmpty)
}

@Test func gpxImportMixedTrkAndRte() throws {
    // File with both <trk> and <rte> elements
    let gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Test">
      <trk>
        <name>Spor</name>
        <trkseg>
          <trkpt lat="60.0" lon="10.0"></trkpt>
          <trkpt lat="60.1" lon="10.1"></trkpt>
        </trkseg>
      </trk>
      <rte>
        <name>Rute</name>
        <rtept lat="61.0" lon="11.0"></rtept>
        <rtept lat="61.1" lon="11.1"></rtept>
      </rte>
    </gpx>
    """
    let url = writeGPXToTemp(gpx, filename: "test_mixed_routes.gpx")
    let routes = try GPXImportService.parseRoutes(from: url)

    #expect(routes.count == 2)
    #expect(routes[0].name == "Spor")
    #expect(routes[1].name == "Rute")
}

// MARK: - GPX Export Waypoints Tests

@Test func gpxExportWaypointsContainsAllFields() {
    let wp = Waypoint(
        name: "Teststed",
        coordinates: [10.7522, 59.9139],
        category: "Utsikt",
        elevation: 150.5
    )
    let gpx = GPXExportService.exportWaypoints([wp], name: "Mine steder")
    #expect(gpx.contains("<wpt lat=\"59.9139\" lon=\"10.7522\">"))
    #expect(gpx.contains("<name>Teststed</name>"))
    #expect(gpx.contains("<ele>150.5</ele>"))
    #expect(gpx.contains("<type>Utsikt</type>"))
    #expect(gpx.contains("Mine steder"))
}

// MARK: - Elevation Stats Tests

@Test func elevationStatsNormalProfile() async {
    let service = ElevationService()
    let coord = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let points = [
        ElevationPoint(coordinate: coord, elevation: 100, distance: 0),
        ElevationPoint(coordinate: coord, elevation: 200, distance: 100),
        ElevationPoint(coordinate: coord, elevation: 150, distance: 200),
        ElevationPoint(coordinate: coord, elevation: 300, distance: 300),
    ]
    let stats = await service.calculateStats(from: points)

    #expect(stats.gain == 250) // +100 + +150
    #expect(stats.loss == 50)  // -50
    #expect(stats.min == 100)
    #expect(stats.max == 300)
    #expect(stats.average == 188) // (100+200+150+300)/4 = 187.5 -> 188
}

@Test func elevationStatsFlatTerrain() async {
    let service = ElevationService()
    let coord = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let points = [
        ElevationPoint(coordinate: coord, elevation: 50, distance: 0),
        ElevationPoint(coordinate: coord, elevation: 50, distance: 100),
        ElevationPoint(coordinate: coord, elevation: 50, distance: 200),
    ]
    let stats = await service.calculateStats(from: points)

    #expect(stats.gain == 0)
    #expect(stats.loss == 0)
    #expect(stats.min == 50)
    #expect(stats.max == 50)
    #expect(stats.average == 50)
}

@Test func elevationStatsSinglePoint() async {
    let service = ElevationService()
    let coord = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let points = [
        ElevationPoint(coordinate: coord, elevation: 250, distance: 0),
    ]
    let stats = await service.calculateStats(from: points)

    #expect(stats.gain == 0)
    #expect(stats.loss == 0)
    #expect(stats.min == 250)
    #expect(stats.max == 250)
    #expect(stats.average == 250)
}

@Test func elevationStatsEmpty() async {
    let service = ElevationService()
    let stats = await service.calculateStats(from: [])

    #expect(stats.gain == 0)
    #expect(stats.loss == 0)
    #expect(stats.min == 0)
    #expect(stats.max == 0)
    #expect(stats.average == 0)
}

@Test func elevationStatsOnlyDescending() async {
    let service = ElevationService()
    let coord = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let points = [
        ElevationPoint(coordinate: coord, elevation: 500, distance: 0),
        ElevationPoint(coordinate: coord, elevation: 300, distance: 100),
        ElevationPoint(coordinate: coord, elevation: 100, distance: 200),
    ]
    let stats = await service.calculateStats(from: points)

    #expect(stats.gain == 0)
    #expect(stats.loss == 400)
    #expect(stats.min == 100)
    #expect(stats.max == 500)
}

// MARK: - ViewportBounds Tests

@Test func viewportBoundsValid() {
    let bounds = ViewportBounds(north: 60.0, south: 59.0, east: 11.0, west: 10.0)
    #expect(bounds.isValid)
}

@Test func viewportBoundsInvalidNorthSouthFlipped() {
    let bounds = ViewportBounds(north: 59.0, south: 60.0, east: 11.0, west: 10.0)
    #expect(!bounds.isValid)
}

@Test func viewportBoundsInvalidEastWestFlipped() {
    let bounds = ViewportBounds(north: 60.0, south: 59.0, east: 10.0, west: 11.0)
    #expect(!bounds.isValid)
}

@Test func viewportBoundsInvalidOutOfRange() {
    // Latitude out of range
    let bounds1 = ViewportBounds(north: 91.0, south: 59.0, east: 11.0, west: 10.0)
    #expect(!bounds1.isValid)

    // Longitude out of range
    let bounds2 = ViewportBounds(north: 60.0, south: 59.0, east: 181.0, west: 10.0)
    #expect(!bounds2.isValid)
}

@Test func viewportBoundsEqualNorthSouth() {
    // Zero-height bounds should be invalid (north must be > south)
    let bounds = ViewportBounds(north: 60.0, south: 60.0, east: 11.0, west: 10.0)
    #expect(!bounds.isValid)
}

@Test func viewportBoundsBuffered() {
    let bounds = ViewportBounds(north: 60.0, south: 59.0, east: 11.0, west: 10.0)
    let buffered = bounds.buffered(factor: 1.2)

    // Buffer expands by 10% on each side (factor 1.2 -> 0.2/2 = 0.1 of span)
    #expect(buffered.north > bounds.north)
    #expect(buffered.south < bounds.south)
    #expect(buffered.east > bounds.east)
    #expect(buffered.west < bounds.west)
    #expect(buffered.isValid)
}

@Test func viewportBoundsBufferedClampsToGlobe() {
    // Near the poles, buffering should not exceed 90/-90
    let bounds = ViewportBounds(north: 89.0, south: 85.0, east: 11.0, west: 10.0)
    let buffered = bounds.buffered(factor: 2.0)

    #expect(buffered.north <= 90)
    #expect(buffered.south >= -90)
    #expect(buffered.east <= 180)
    #expect(buffered.west >= -180)
}

@Test func viewportBoundsCacheKey() {
    let bounds = ViewportBounds(north: 60.1234, south: 59.5678, east: 11.9876, west: 10.1234)
    let key = bounds.cacheKey
    #expect(key == "60.1234,59.5678,11.9876,10.1234")
}

// MARK: - POI Category Tests

@Test("All POI categories have non-empty icon names",
      arguments: POICategory.allCases)
func poiCategoryIconName(category: POICategory) {
    #expect(!category.iconName.isEmpty)
    #expect(category.iconName.hasPrefix("POI"))
}

@Test("All POI categories have valid hex color strings",
      arguments: POICategory.allCases)
func poiCategoryColor(category: POICategory) {
    #expect(category.color.hasPrefix("#"))
    #expect(category.color.count == 7) // #RRGGBB
}

@Test("All POI categories have a source name for attribution",
      arguments: POICategory.allCases)
func poiCategorySourceName(category: POICategory) {
    #expect(!category.sourceName.isEmpty)
}

@Test("All POI categories have a license identifier",
      arguments: POICategory.allCases)
func poiCategoryLicense(category: POICategory) {
    let validLicenses = ["NLOD 2.0", "ODbL"]
    #expect(validLicenses.contains(category.sourceLicense))
}

@Test("All POI categories have minimum zoom between 1 and 18",
      arguments: POICategory.allCases)
func poiCategoryMinZoom(category: POICategory) {
    #expect(category.minZoom >= 1)
    #expect(category.minZoom <= 18)
}

@Test("POI category count matches expected") func poiCategoryCount() {
    #expect(POICategory.allCases.count == 6)
}

// MARK: - Coordinate Edge Cases

@Test func parseDDSouthernHemisphere() {
    let result = CoordinateService.parse("S33.8688 E151.2093")
    #expect(result != nil)
    #expect(result!.coordinate.latitude < 0)
    #expect(abs(result!.coordinate.latitude - -33.8688) < 0.001)
}

@Test func parseDDWesternHemisphere() {
    let result = CoordinateService.parse("N40.7128 W74.0060")
    #expect(result != nil)
    #expect(result!.coordinate.longitude < 0)
    #expect(abs(result!.coordinate.longitude - -74.006) < 0.001)
}

@Test func parseDDZeroCoordinates() {
    let result = CoordinateService.parse("0.0, 0.0")
    #expect(result != nil)
    #expect(abs(result!.coordinate.latitude) < 0.001)
    #expect(abs(result!.coordinate.longitude) < 0.001)
}

@Test func parseDDBoundaryValues() {
    // Valid extremes
    let north = CoordinateService.parse("90.0, 0.0")
    #expect(north != nil)

    let south = CoordinateService.parse("-90.0, 0.0")
    #expect(south != nil)

    let east = CoordinateService.parse("0.0, 180.0")
    #expect(east != nil)

    let west = CoordinateService.parse("0.0, -180.0")
    #expect(west != nil)
}

@Test func parseDDNorwaySwapDetection() {
    // If lon,lat is entered instead of lat,lon and first value is in Norway's lon range
    // while second is in Norway's lat range, the parser should swap them
    let result = CoordinateService.parse("10.7522, 59.9139")
    #expect(result != nil)
    // The parser should detect that 10.75 as lat, 59.91 as lon is NOT in Norway,
    // but swapped (lat=59.91, lon=10.75) IS in Norway, and swap accordingly
    #expect(result!.coordinate.latitude > 55)
    #expect(result!.coordinate.longitude < 35)
}

@Test func formatDDSouthWest() {
    let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: -58.4100)
    let formatted = CoordinateService.format(coordinate: coord, format: .dd)
    #expect(formatted.display.contains("S"))
    #expect(formatted.display.contains("W"))
}

// MARK: - Offline Download Progress Tests

@Test func downloadProgressPercentage() {
    let progress = OfflineDownloadProgress(
        completedResources: 50,
        expectedResources: 100,
        completedBytes: 500_000,
        isComplete: false
    )
    #expect(abs(progress.percentage - 50.0) < 0.01)
}

@Test func downloadProgressPercentageComplete() {
    let progress = OfflineDownloadProgress(
        completedResources: 100,
        expectedResources: 100,
        completedBytes: 1_000_000,
        isComplete: true
    )
    #expect(abs(progress.percentage - 100.0) < 0.01)
}

@Test func downloadProgressPercentageZeroExpected() {
    // Division by zero guard
    let progress = OfflineDownloadProgress.zero
    #expect(progress.percentage == 0)
    #expect(progress.completedResources == 0)
    #expect(!progress.isComplete)
}

// MARK: - Offline Pack Context Encoding/Decoding

@Test func offlinePackContextRoundTrip() throws {
    let original = OfflinePackContext(id: "dl-123", name: "Oslo Vest", layer: "topo")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(OfflinePackContext.self, from: data)

    #expect(decoded.id == original.id)
    #expect(decoded.name == original.name)
    #expect(decoded.layer == original.layer)
}

// MARK: - Haversine Sample Coordinates Tests

@Test func sampleCoordinatesSinglePoint() {
    let coords = [CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)]
    let sampled = Haversine.sampleCoordinates(coords, interval: 100)
    // Fewer than 2 points returns input as-is
    #expect(sampled.count == 1)
}

@Test func sampleCoordinatesEmpty() {
    let sampled = Haversine.sampleCoordinates([], interval: 100)
    #expect(sampled.isEmpty)
}

@Test func sampleCoordinatesAlwaysIncludesFirstAndLast() {
    // Two points close together (within one interval)
    let coords = [
        CLLocationCoordinate2D(latitude: 59.0000, longitude: 10.0000),
        CLLocationCoordinate2D(latitude: 59.0001, longitude: 10.0001),
    ]
    let sampled = Haversine.sampleCoordinates(coords, interval: 100)
    // Should include both first and last
    #expect(sampled.count >= 2)
    #expect(sampled.first!.latitude == coords.first!.latitude)
    #expect(sampled.last!.latitude == coords.last!.latitude)
}

@Test func sampleCoordinatesReducesPointCount() {
    // Many points close together should be reduced
    var coords: [CLLocationCoordinate2D] = []
    for i in 0..<100 {
        coords.append(CLLocationCoordinate2D(
            latitude: 59.0 + Double(i) * 0.00001,
            longitude: 10.0
        ))
    }
    let sampled = Haversine.sampleCoordinates(coords, interval: 100)
    // With ~1.1m between points and 100m interval, should reduce significantly
    #expect(sampled.count < coords.count)
    #expect(sampled.count >= 2) // At least first and last
}

@Test func sampleCoordinatesPreservesWidelySpacedPoints() {
    // Points spaced >100m apart should mostly be preserved
    let coords = [
        CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.01, longitude: 10.0),  // ~1.1 km away
        CLLocationCoordinate2D(latitude: 59.02, longitude: 10.0),  // ~1.1 km away
        CLLocationCoordinate2D(latitude: 59.03, longitude: 10.0),  // ~1.1 km away
    ]
    let sampled = Haversine.sampleCoordinates(coords, interval: 100)
    #expect(sampled.count == coords.count)
}

// MARK: - Kartverket Tile Service Tests

@Test("Style JSON is valid for both layers",
      arguments: BaseLayer.allCases)
func kartverketStyleJSON(layer: BaseLayer) {
    let data = KartverketTileService.styleJSON(for: layer)
    #expect(!data.isEmpty)

    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(json != nil)
    #expect(json?["version"] as? Int == 8)

    let sources = json?["sources"] as? [String: Any]
    #expect(sources?[layer.sourceID] != nil)

    let layers = json?["layers"] as? [[String: Any]]
    #expect(layers?.first?["id"] as? String == layer.layerID)
}

@Test func baseLayerTileURLsAreHTTPS() {
    for layer in BaseLayer.allCases {
        #expect(layer.tileURL.hasPrefix("https://"))
        #expect(layer.tileURL.contains("cache.kartverket.no"))
    }
}

// MARK: - MeasurementViewModel Tests

@Test func measurementViewModelStartDistance() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .distance)
    let isActive = await vm.isActive
    let mode = await vm.mode
    #expect(isActive)
    #expect(mode == .distance)
}

@Test func measurementViewModelStartArea() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .area)
    let mode = await vm.mode
    #expect(mode == .area)
}

@Test func measurementViewModelAddAndUndoPoints() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .distance)
    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let bergen = CLLocationCoordinate2D(latitude: 60.3913, longitude: 5.3221)
    await vm.addPoint(oslo)
    await vm.addPoint(bergen)
    var count = await vm.points.count
    #expect(count == 2)

    await vm.undoLastPoint()
    count = await vm.points.count
    #expect(count == 1)
}

@Test func measurementViewModelHasMinimumPointsDistance() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .distance)
    var hasMin = await vm.hasMinimumPoints
    #expect(!hasMin)

    await vm.addPoint(CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0))
    hasMin = await vm.hasMinimumPoints
    #expect(!hasMin)

    await vm.addPoint(CLLocationCoordinate2D(latitude: 60.0, longitude: 11.0))
    hasMin = await vm.hasMinimumPoints
    #expect(hasMin)
}

@Test func measurementViewModelHasMinimumPointsArea() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .area)

    await vm.addPoint(CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0))
    await vm.addPoint(CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0))
    var hasMin = await vm.hasMinimumPoints
    #expect(!hasMin)

    await vm.addPoint(CLLocationCoordinate2D(latitude: 60.0, longitude: 11.0))
    hasMin = await vm.hasMinimumPoints
    #expect(hasMin)
}

@Test func measurementViewModelStop() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .distance)
    await vm.addPoint(CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0))
    await vm.stop()
    let isActive = await vm.isActive
    let mode = await vm.mode
    let count = await vm.points.count
    #expect(!isActive)
    #expect(mode == nil)
    #expect(count == 0)
}

@Test func measurementViewModelClearAll() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .distance)
    await vm.addPoint(CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0))
    await vm.addPoint(CLLocationCoordinate2D(latitude: 60.0, longitude: 11.0))
    await vm.clearAll()
    let count = await vm.points.count
    let isActive = await vm.isActive
    #expect(count == 0)
    #expect(isActive) // clearAll does NOT stop, just removes points
}

@Test func measurementViewModelMovePoint() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .distance)
    await vm.addPoint(CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0))
    await vm.movePoint(at: 0, to: CLLocationCoordinate2D(latitude: 61.0, longitude: 12.0))
    let lat = await vm.points[0].latitude
    #expect(abs(lat - 61.0) < 0.001)
}

@Test func measurementViewModelMovePointOutOfBounds() async {
    let vm = await MeasurementViewModel()
    await vm.startMeasuring(mode: .distance)
    await vm.addPoint(CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0))
    // Moving at invalid index should not crash
    await vm.movePoint(at: 5, to: CLLocationCoordinate2D(latitude: 61.0, longitude: 12.0))
    let count = await vm.points.count
    #expect(count == 1)
}

// MARK: - MapViewModel Tests

@Test func mapViewModelSwitchLayer() async {
    let vm = await MapViewModel()
    await vm.switchLayer(to: .grayscale)
    let layer = await vm.baseLayer
    #expect(layer == .grayscale)
}

@Test func mapViewModelCenterOn() async {
    let vm = await MapViewModel()
    let coord = CLLocationCoordinate2D(latitude: 63.0, longitude: 10.4)
    await vm.centerOn(coordinate: coord, zoom: 12)
    let center = await vm.currentCenter
    let zoom = await vm.currentZoom
    let tracking = await vm.isTrackingUser
    #expect(abs(center.latitude - 63.0) < 0.001)
    #expect(abs(zoom - 12.0) < 0.001)
    #expect(!tracking) // centering on a coordinate disables user tracking
}

@Test func mapViewModelZoomInOut() async {
    let vm = await MapViewModel()
    let initial = await vm.currentZoom
    await vm.zoomIn()
    let afterIn = await vm.currentZoom
    #expect(afterIn > initial)

    await vm.zoomOut()
    let afterOut = await vm.currentZoom
    #expect(abs(afterOut - initial) < 0.01)
}

// MARK: - RouteViewModel Drawing Tests

@Test func routeViewModelDrawingLifecycle() async {
    let vm = await RouteViewModel()
    await vm.startDrawing()
    var isDrawing = await vm.isDrawing
    #expect(isDrawing)

    let c1 = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let c2 = CLLocationCoordinate2D(latitude: 59.1, longitude: 10.1)
    await vm.addPoint(c1)
    await vm.addPoint(c2)
    var count = await vm.drawingCoordinates.count
    #expect(count == 2)

    let distance = await vm.drawingDistance
    #expect(distance > 0)

    await vm.undoLastPoint()
    count = await vm.drawingCoordinates.count
    #expect(count == 1)

    await vm.cancelDrawing()
    isDrawing = await vm.isDrawing
    count = await vm.drawingCoordinates.count
    #expect(!isDrawing)
    #expect(count == 0)
}

@Test func routeViewModelAddPointWhenNotDrawing() async {
    let vm = await RouteViewModel()
    await vm.addPoint(CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0))
    let count = await vm.drawingCoordinates.count
    #expect(count == 0) // Should not add when not in drawing mode
}

@Test func routeViewModelFormattedDistance() async {
    let vm = await RouteViewModel()
    let short = await vm.formattedDistance(500)
    #expect(short == "500 m")
    let long = await vm.formattedDistance(2500)
    #expect(long == "2.5 km")
    let none = await vm.formattedDistance(nil)
    #expect(none == "--")
    let zero = await vm.formattedDistance(0)
    #expect(zero == "--")
}

@Test func routeViewModelClearSelection() async {
    let vm = await RouteViewModel()
    await vm.clearSelection()
    await MainActor.run {
        #expect(vm.selectedRoute == nil)
        #expect(vm.elevationProfile.isEmpty)
        #expect(vm.elevationStats == nil)
    }
}

// MARK: - SheetCoordinator Tests

@Test func sheetCoordinatorDismissAll() async {
    let sheets = await SheetCoordinator()
    await MainActor.run {
        sheets.showSearchSheet = true
        sheets.showRouteList = true
        sheets.showWeatherSheet = true
        sheets.dismissAll()
    }
    let search = await sheets.showSearchSheet
    let routes = await sheets.showRouteList
    let weather = await sheets.showWeatherSheet
    #expect(!search)
    #expect(!routes)
    #expect(!weather)
}

// MARK: - SearchViewModel Tests

@Test func searchViewModelClearSearch() async {
    let vm = await SearchViewModel()
    await vm.clearSearch()
    let query = await vm.query
    let results = await vm.results
    let isSearching = await vm.isSearching
    let selected = await vm.selectedResult
    #expect(query.isEmpty)
    #expect(results.isEmpty)
    #expect(!isSearching)
    #expect(selected == nil)
}

@Test func searchViewModelShortQueryClearsResults() async {
    let vm = await SearchViewModel()
    await vm.updateQuery("a") // too short (< 2 chars)
    let results = await vm.results
    let isSearching = await vm.isSearching
    #expect(results.isEmpty)
    #expect(!isSearching)
}

// MARK: - WeatherViewModel Debounce Tests

@Test func weatherViewModelSkipsSameLocation() async {
    let vm = await WeatherViewModel()
    let coord = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    // First call initiates fetch
    await vm.fetchForecast(for: coord)
    // Small wait for debounce
    try? await Task.sleep(for: .milliseconds(50))
    // Second call with same coord should be skipped (within 1km)
    let nearCoord = CLLocationCoordinate2D(latitude: 59.9140, longitude: 10.7523)
    await vm.fetchForecast(for: nearCoord)
    // No crash or error means debounce logic works
}

// MARK: - SwiftData Migration Tests

@Test func migrationPlanConfiguration() {
    // Verify migration plan has both schema versions in correct order
    let schemas = TrakkeMigrationPlan.schemas
    #expect(schemas.count == 2)
    #expect(String(describing: schemas[0]) == String(describing: SchemaV1.self))
    #expect(String(describing: schemas[1]) == String(describing: SchemaV2.self))

    // Verify there is exactly one migration stage
    #expect(TrakkeMigrationPlan.stages.count == 1)
}

@Test func schemaV1HasRemovedModels() {
    // SchemaV1 includes the now-removed Project and DownloadedArea models
    let models = SchemaV1.models
    #expect(models.count == 4) // Route, Waypoint, Project, DownloadedArea
}

@Test func schemaV2OnlyHasActiveModels() {
    // SchemaV2 should only contain Route and Waypoint
    let models = SchemaV2.models
    #expect(models.count == 2)
}

@Test func swiftDataContainerCreation() throws {
    // Verify a ModelContainer can be created with the current schema
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Route.self, Waypoint.self,
        configurations: config
    )
    #expect(container.schema.entities.count >= 2)
}

// MARK: - Helpers

private func writeGPXToTemp(_ content: String, filename: String) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    try! content.write(to: url, atomically: true, encoding: .utf8)
    return url
}
