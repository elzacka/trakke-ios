import Testing
import Foundation
import CoreLocation
@testable import Trakke

// MARK: - Bearing Tests

@Test func bearingNorthward() {
    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let trondheim = CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951)
    let bearing = Bearing.bearing(from: oslo, to: trondheim)
    // Oslo to Trondheim is roughly north (~357 degrees)
    #expect(bearing > 350 || bearing < 10)
}

@Test func bearingWestward() {
    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let bergen = CLLocationCoordinate2D(latitude: 60.3913, longitude: 5.3221)
    let bearing = Bearing.bearing(from: oslo, to: bergen)
    // Oslo to Bergen is roughly west (~283 degrees)
    #expect(bearing > 270 && bearing < 300)
}

@Test func bearingSamePoint() {
    let coord = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let bearing = Bearing.bearing(from: coord, to: coord)
    // Bearing to same point is indeterminate but should not crash
    #expect(bearing >= 0 && bearing < 360 || bearing.isNaN)
}

@Test func bearingOppositeDirections() {
    let a = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let b = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let bearingAB = Bearing.bearing(from: a, to: b)
    let bearingBA = Bearing.bearing(from: b, to: a)
    // Should be roughly opposite (~180 degrees apart)
    let diff = abs(bearingAB - bearingBA)
    #expect(abs(diff - 180) < 5)
}

// MARK: - Cross-Track Distance Tests

@Test func crossTrackDistancePointOnLine() {
    let start = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let end = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    // Point roughly on the line (same longitude)
    let point = CLLocationCoordinate2D(latitude: 59.5, longitude: 10.0)
    let distance = Bearing.crossTrackDistance(point: point, lineStart: start, lineEnd: end)
    #expect(distance < 10) // Should be very close to 0
}

@Test func crossTrackDistancePointOffLine() {
    let start = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let end = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    // Point ~100m east of the line
    let point = CLLocationCoordinate2D(latitude: 59.5, longitude: 10.0018)
    let distance = Bearing.crossTrackDistance(point: point, lineStart: start, lineEnd: end)
    #expect(distance > 50 && distance < 200)
}

// MARK: - Closest Point on Segment Tests

@Test func closestPointOnSegmentMiddle() {
    let start = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let end = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let point = CLLocationCoordinate2D(latitude: 59.5, longitude: 10.001)
    let (snapped, dist) = Bearing.closestPointOnSegment(point: point, segmentStart: start, segmentEnd: end)
    // Snapped point should have latitude close to 59.5
    #expect(abs(snapped.latitude - 59.5) < 0.01)
    // Distance should be small (point is very near the line)
    #expect(dist < 200)
}

@Test func closestPointOnSegmentAtStart() {
    let start = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let end = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    // Point behind the segment start
    let point = CLLocationCoordinate2D(latitude: 58.5, longitude: 10.0)
    let (snapped, _) = Bearing.closestPointOnSegment(point: point, segmentStart: start, segmentEnd: end)
    // Should snap to start
    #expect(abs(snapped.latitude - start.latitude) < 0.001)
}

@Test func closestPointOnSegmentAtEnd() {
    let start = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let end = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    // Point beyond the segment end
    let point = CLLocationCoordinate2D(latitude: 60.5, longitude: 10.0)
    let (snapped, _) = Bearing.closestPointOnSegment(point: point, segmentStart: start, segmentEnd: end)
    // Should snap to end
    #expect(abs(snapped.latitude - end.latitude) < 0.001)
}

@Test func closestPointDegenerateSegment() {
    let point = CLLocationCoordinate2D(latitude: 59.5, longitude: 10.0)
    let same = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let (snapped, _) = Bearing.closestPointOnSegment(point: point, segmentStart: same, segmentEnd: same)
    #expect(abs(snapped.latitude - same.latitude) < 0.001)
}

// MARK: - Interpolate Tests

@Test func interpolateEndpoints() {
    let start = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let end = CLLocationCoordinate2D(latitude: 60.0, longitude: 11.0)

    let atStart = Bearing.interpolate(from: start, to: end, fraction: 0)
    #expect(abs(atStart.latitude - start.latitude) < 0.001)

    let atEnd = Bearing.interpolate(from: start, to: end, fraction: 1)
    #expect(abs(atEnd.latitude - end.latitude) < 0.001)
}

@Test func interpolateMidpoint() {
    let start = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let end = CLLocationCoordinate2D(latitude: 61.0, longitude: 10.0)
    let mid = Bearing.interpolate(from: start, to: end, fraction: 0.5)
    #expect(abs(mid.latitude - 60.0) < 0.01)
}

// MARK: - NavigationService Snap-to-Track Tests

@Test func snapToTrackNearStart() async {
    let service = NavigationService()
    let route = [
        CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.1, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.2, longitude: 10.0),
    ]
    let cumDist = Haversine.cumulativeDistances(coordinates: route)
    let userLoc = CLLocationCoordinate2D(latitude: 59.01, longitude: 10.0001)

    let result = await service.snapToTrack(
        location: userLoc,
        routeCoordinates: route,
        cumulativeDistances: cumDist
    )
    #expect(result != nil)
    #expect(result!.segmentIndex == 0)
    #expect(result!.crossTrackDistance < 50)
    #expect(result!.alongTrackDistance > 0)
}

@Test func snapToTrackNearMiddle() async {
    let service = NavigationService()
    let route = [
        CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.1, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.2, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.3, longitude: 10.0),
    ]
    let cumDist = Haversine.cumulativeDistances(coordinates: route)
    let userLoc = CLLocationCoordinate2D(latitude: 59.15, longitude: 10.0001)

    let result = await service.snapToTrack(
        location: userLoc,
        routeCoordinates: route,
        cumulativeDistances: cumDist
    )
    #expect(result != nil)
    #expect(result!.segmentIndex == 1)
    #expect(result!.crossTrackDistance < 50)
}

@Test func snapToTrackFarFromRoute() async {
    let service = NavigationService()
    let route = [
        CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.1, longitude: 10.0),
    ]
    let cumDist = Haversine.cumulativeDistances(coordinates: route)
    // 1 degree off = ~60 km
    let userLoc = CLLocationCoordinate2D(latitude: 59.05, longitude: 11.0)

    let result = await service.snapToTrack(
        location: userLoc,
        routeCoordinates: route,
        cumulativeDistances: cumDist
    )
    #expect(result != nil)
    #expect(result!.crossTrackDistance > 10_000) // Far off track
}

@Test func snapToTrackTooFewPoints() async {
    let service = NavigationService()
    let route = [CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)]
    let cumDist = Haversine.cumulativeDistances(coordinates: route)
    let userLoc = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)

    let result = await service.snapToTrack(
        location: userLoc,
        routeCoordinates: route,
        cumulativeDistances: cumDist
    )
    #expect(result == nil)
}

// MARK: - NavigationService Remaining Distance Tests

@Test func remainingDistanceFromStart() async {
    let service = NavigationService()
    let route = [
        CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.1, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.2, longitude: 10.0),
    ]
    let totalDist = Haversine.totalDistance(coordinates: route)
    let remaining = await service.remainingDistance(
        fromIndex: 0,
        snappedCoordinate: route[0],
        routeCoordinates: route
    )
    // From start, remaining should be approximately equal to total distance
    #expect(abs(remaining - totalDist) < 100)
}

@Test func remainingDistanceFromEnd() async {
    let service = NavigationService()
    let route = [
        CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        CLLocationCoordinate2D(latitude: 59.1, longitude: 10.0),
    ]
    let remaining = await service.remainingDistance(
        fromIndex: 0,
        snappedCoordinate: route.last!,
        routeCoordinates: route
    )
    // Snapped at the end point of segment 0 = route end
    #expect(remaining < 10)
}

// MARK: - NavigationService Estimated Time (Naismith) Tests

@Test func estimatedTimeFlatTerrain() async {
    let service = NavigationService()
    // 5 km flat = ~1 hour at 5 km/h
    let time = await service.estimatedTime(remainingDistance: 5000, remainingGain: 0)
    let hours = time / 3600
    #expect(abs(hours - 1.0) < 0.01)
}

@Test func estimatedTimeWithClimb() async {
    let service = NavigationService()
    // 5 km + 500m climb: 1 hour flat + 50 min climb = ~1 hour 50 min
    let time = await service.estimatedTime(remainingDistance: 5000, remainingGain: 500)
    let minutes = time / 60
    #expect(minutes > 100 && minutes < 120)
}

// MARK: - NavigationService Remaining Elevation Tests

@Test func remainingElevationFromStart() async {
    let service = NavigationService()
    let coord = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let profile = [
        ElevationPoint(coordinate: coord, elevation: 100, distance: 0),
        ElevationPoint(coordinate: coord, elevation: 300, distance: 1000),
        ElevationPoint(coordinate: coord, elevation: 200, distance: 2000),
        ElevationPoint(coordinate: coord, elevation: 400, distance: 3000),
    ]
    let (gain, loss) = await service.remainingElevation(
        fromAlongTrackDistance: 0,
        elevationProfile: profile
    )
    // Gain: +200 + +200 = 400, Loss: -100
    #expect(abs(gain - 400) < 1)
    #expect(abs(loss - 100) < 1)
}

@Test func remainingElevationFromMiddle() async {
    let service = NavigationService()
    let coord = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let profile = [
        ElevationPoint(coordinate: coord, elevation: 100, distance: 0),
        ElevationPoint(coordinate: coord, elevation: 300, distance: 1000),
        ElevationPoint(coordinate: coord, elevation: 200, distance: 2000),
        ElevationPoint(coordinate: coord, elevation: 400, distance: 3000),
    ]
    let (gain, loss) = await service.remainingElevation(
        fromAlongTrackDistance: 1500,
        elevationProfile: profile
    )
    // startIndex finds first point with distance >= 1500 -> index 2 (2000m)
    // From index 2: 200->400 = +200 gain, 0 loss
    #expect(abs(gain - 200) < 1)
    #expect(abs(loss - 0) < 1)
}

@Test func remainingElevationEmpty() async {
    let service = NavigationService()
    let (gain, loss) = await service.remainingElevation(
        fromAlongTrackDistance: 0,
        elevationProfile: []
    )
    #expect(gain == 0)
    #expect(loss == 0)
}

// MARK: - Polyline6 Decoder Tests

@Test func polyline6DecodeRoundTrip() {
    // Manually encode two known points using polyline6 algorithm
    // Oslo: lat=59.913900, lon=10.752200
    // Encoded value = round(59.913900 * 1e6) = 59913900
    let encoded = encodePolyline6([
        CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
        CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951),
    ])
    let decoded = Polyline6Decoder.decode(encoded)
    #expect(decoded.count == 2)
    #expect(abs(decoded[0].latitude - 59.9139) < 0.001)
    #expect(abs(decoded[0].longitude - 10.7522) < 0.001)
    #expect(abs(decoded[1].latitude - 63.4305) < 0.001)
    #expect(abs(decoded[1].longitude - 10.3951) < 0.001)
}

@Test func polyline6DecodeEmpty() {
    let coords = Polyline6Decoder.decode("")
    #expect(coords.isEmpty)
}

@Test func polyline6DecodeReturnsValidCoordinates() {
    // Encode three points near Oslo and verify decoded coordinates are valid
    let encoded = encodePolyline6([
        CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
        CLLocationCoordinate2D(latitude: 59.9200, longitude: 10.7600),
        CLLocationCoordinate2D(latitude: 59.9300, longitude: 10.7700),
    ])
    let coords = Polyline6Decoder.decode(encoded)
    #expect(coords.count == 3)
    for coord in coords {
        #expect(coord.latitude >= -90 && coord.latitude <= 90)
        #expect(coord.longitude >= -180 && coord.longitude <= 180)
    }
}

// MARK: - NavigationState Model Tests

@Test func navigationModeValues() {
    let route = NavigationMode.route
    let compass = NavigationMode.compass
    // Simply verify they are distinct values
    #expect(route != compass)
}

@Test("NavigationCameraMode raw values")
func cameraModeRawValues() {
    #expect(NavigationCameraMode.northUp.rawValue == "northUp")
    #expect(NavigationCameraMode.courseUp.rawValue == "courseUp")
}

@Test func gpsQualityFromAccuracy() {
    #expect(GPSQuality(accuracy: 5) == .good)
    #expect(GPSQuality(accuracy: 19) == .good)
    #expect(GPSQuality(accuracy: 25) == .reduced)
    #expect(GPSQuality(accuracy: 49) == .reduced)
    #expect(GPSQuality(accuracy: 50) == .lost)
    #expect(GPSQuality(accuracy: 100) == .lost)
    #expect(GPSQuality(accuracy: -1) == .lost)
}

@Test func snapResultProperties() {
    let result = SnapResult(
        segmentIndex: 5,
        snappedCoordinate: CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
        crossTrackDistance: 25.3,
        alongTrackDistance: 1500.0,
        routeBearing: 45.0
    )
    #expect(result.segmentIndex == 5)
    #expect(abs(result.crossTrackDistance - 25.3) < 0.01)
    #expect(abs(result.alongTrackDistance - 1500.0) < 0.01)
    #expect(abs(result.routeBearing - 45.0) < 0.01)
}

@Test func navigationProgressProperties() {
    let progress = NavigationProgress(
        distanceRemaining: 5000,
        distanceTraveled: 3000,
        totalDistance: 8000,
        elevationGainRemaining: 200,
        elevationLossRemaining: 100,
        estimatedTimeRemaining: 3600,
        currentSegmentIndex: 10,
        fractionCompleted: 0.375
    )
    #expect(abs(progress.fractionCompleted - 0.375) < 0.001)
    #expect(progress.totalDistance == 8000)
    #expect(progress.currentSegmentIndex == 10)
}

@Test func turnTypeValues() {
    // Verify raw values for key turn types
    #expect(TurnType.straight.rawValue == "straight")
    #expect(TurnType.right.rawValue == "right")
    #expect(TurnType.left.rawValue == "left")
    #expect(TurnType.destination.rawValue == "destination")
    #expect(TurnType.ferry.rawValue == "ferry")
}

// MARK: - NavigationViewModel Tests

@Test func navigationViewModelStartCompass() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    let isActive = await vm.isActive
    let mode = await vm.mode
    let destination = await vm.destination
    #expect(isActive)
    #expect(mode == .compass)
    #expect(destination != nil)
    #expect(abs(destination!.latitude - 60.0) < 0.001)
}

@Test func navigationViewModelStop() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)
    await vm.stopNavigation()

    let isActive = await vm.isActive
    let destination = await vm.destination
    let routeCoords = await vm.routeCoordinates
    #expect(!isActive)
    #expect(destination == nil)
    #expect(routeCoords.isEmpty)
}

@Test func navigationViewModelFollowRoute() async {
    let vm = await NavigationViewModel()
    let route = Route(name: "Testrute")
    route.coordinates = [
        [10.0, 59.0],
        [10.0, 59.1],
        [10.0, 59.2],
    ]
    route.distance = 22000.0

    await vm.startFollowingRoute(route: route)

    let isActive = await vm.isActive
    let mode = await vm.mode
    let routeCoords = await vm.routeCoordinates
    #expect(isActive)
    #expect(mode == .route)
    #expect(routeCoords.count == 3)
}

@Test func navigationViewModelSwitchToCompass() async {
    let vm = await NavigationViewModel()
    let route = Route(name: "Testrute")
    route.coordinates = [
        [10.0, 59.0],
        [10.0, 59.1],
    ]
    await vm.startFollowingRoute(route: route)
    await vm.switchToCompass()

    let mode = await vm.mode
    let routeCoords = await vm.routeCoordinates
    let destination = await vm.destination
    #expect(mode == .compass)
    #expect(routeCoords.isEmpty)
    #expect(destination != nil)
}

@Test func navigationViewModelToggleCameraMode() async {
    let vm = await NavigationViewModel()
    let initial = await vm.cameraMode
    #expect(initial == .northUp)

    await vm.toggleCameraMode()
    let toggled = await vm.cameraMode
    #expect(toggled == .courseUp)

    await vm.toggleCameraMode()
    let toggledBack = await vm.cameraMode
    #expect(toggledBack == .northUp)
}

@Test func navigationViewModelDismissDeviation() async {
    let vm = await NavigationViewModel()
    await vm.dismissDeviation()
    let isOffTrack = await vm.isOffTrack
    #expect(!isOffTrack)
}

@Test func navigationViewModelFollowRouteMinimumPoints() async {
    let vm = await NavigationViewModel()
    let route = Route(name: "Kort rute")
    route.coordinates = [[10.0, 59.0]] // Only 1 point, not enough

    await vm.startFollowingRoute(route: route)

    let isActive = await vm.isActive
    #expect(!isActive) // Should not activate with < 2 points
}

@Test func navigationViewModelCompassUpdate() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    let location = CLLocation(latitude: 59.5, longitude: 10.0)
    await vm.processLocationUpdate(location)

    let distance = await vm.compassDistance
    let bearing = await vm.compassBearing
    #expect(distance > 50_000) // ~55 km
    #expect(bearing >= 0 && bearing < 360)
}

@Test func navigationViewModelCompassArrival() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    // Simulate being very close to destination
    let location = CLLocation(latitude: 59.00001, longitude: 10.00001)
    await vm.processLocationUpdate(location)

    let arrived = await vm.hasArrived
    #expect(arrived)
}

// MARK: - ComputedRoute Tests

@Test func computedRouteProperties() {
    let route = ComputedRoute(
        coordinates: [
            CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0),
            CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0),
        ],
        distance: 111000,
        duration: 3600,
        ascent: 500,
        descent: 300,
        instructions: [],
        summary: "Test"
    )
    #expect(route.coordinates.count == 2)
    #expect(route.distance == 111000)
    #expect(route.duration == 3600)
    #expect(route.summary == "Test")
}

// MARK: - RoutingError Tests

@Test func routingErrorDescriptions() {
    #expect(RoutingError.noRoute.errorDescription != nil)
    #expect(RoutingError.offline.errorDescription != nil)
    #expect(RoutingError.rateLimited.errorDescription != nil)
    #expect(RoutingError.serverError(500).errorDescription!.contains("500"))
    #expect(RoutingError.decodingError.errorDescription != nil)
}

// MARK: - Polyline6 Encoding Helper (for testing)

private func encodePolyline6(_ coordinates: [CLLocationCoordinate2D]) -> String {
    var result = ""
    var prevLat = 0
    var prevLon = 0

    for coord in coordinates {
        let lat = Int(round(coord.latitude * 1e6))
        let lon = Int(round(coord.longitude * 1e6))
        result += encodeValue(lat - prevLat)
        result += encodeValue(lon - prevLon)
        prevLat = lat
        prevLon = lon
    }
    return result
}

private func encodeValue(_ value: Int) -> String {
    var v = value < 0 ? ~(value << 1) : (value << 1)
    var result = ""
    while v >= 0x20 {
        let char = Character(UnicodeScalar((v & 0x1F) + 63 + 0x20)!)
        result.append(char)
        v >>= 5
    }
    result.append(Character(UnicodeScalar(v + 63)!))
    return result
}
