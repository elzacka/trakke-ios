import Testing
import CoreLocation
@testable import Trakke

// MARK: - Model Tests

@Test func routeCreation() async throws {
    let route = Route(name: "Testtur")
    #expect(route.name == "Testtur")
    #expect(route.id.hasPrefix("route-"))
    #expect(route.coordinates.isEmpty)
}

@Test func waypointCreation() async throws {
    let wp = Waypoint(name: "Utsiktspunkt", coordinates: [10.7522, 59.9139])
    #expect(wp.name == "Utsiktspunkt")
    #expect(wp.id.hasPrefix("wp-"))
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
    #expect(GPXExportService.sanitizeFilename("") == "route.gpx")
}

// MARK: - Route Distance Calculation

@Test func routeServiceCalculateDistance() {
    let coords: [[Double]] = [[10.7522, 59.9139], [10.7600, 59.9200]]
    let distance = RouteService.calculateDistance(coordinates: coords)
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

// MARK: - Weather Symbol Mapping Tests

@Test func weatherSymbolMapping() {
    #expect(WeatherViewModel.sfSymbol(for: "clearsky_day") == "sun.max.fill")
    #expect(WeatherViewModel.sfSymbol(for: "clearsky_night") == "moon.stars.fill")
    #expect(WeatherViewModel.sfSymbol(for: "rain") == "cloud.rain.fill")
    #expect(WeatherViewModel.sfSymbol(for: "heavysnow") == "cloud.snow.fill")
    #expect(WeatherViewModel.sfSymbol(for: "unknown_symbol") == "cloud.fill")
}

@Test func weatherWindDirection() {
    #expect(WeatherService.windDirectionName(0) == "N")
    #expect(WeatherService.windDirectionName(90) == "O")
    #expect(WeatherService.windDirectionName(180) == "S")
    #expect(WeatherService.windDirectionName(270) == "V")
}
