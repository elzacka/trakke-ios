import Testing
import Foundation
import CoreLocation
@testable import Trakke

// MARK: - ActivityTrackingService Tests

@Test func activityTrackingRejectsLowAccuracyPoints() async {
    let service = ActivityTrackingService()
    await service.start()

    // Accuracy > 50m should be rejected
    let badLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 100,
        verticalAccuracy: 10,
        timestamp: Date()
    )
    await service.addLocation(badLocation)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 0)
}

@Test func activityTrackingRejectsNegativeAccuracy() async {
    let service = ActivityTrackingService()
    await service.start()

    let badLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: -1,
        verticalAccuracy: 10,
        timestamp: Date()
    )
    await service.addLocation(badLocation)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 0)
}

@Test func activityTrackingAcceptsGoodAccuracy() async {
    let service = ActivityTrackingService()
    await service.start()

    let goodLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 10,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(goodLocation)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 1)
}

@Test func activityTrackingMinDistanceFilter() async {
    let service = ActivityTrackingService()
    await service.start()

    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    // Second point very close (< 10m) — should be rejected
    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.90001, longitude: 10.70001),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(5)
    )
    await service.addLocation(loc2)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 1)
    #expect(stats.distance == 0)
}

@Test func activityTrackingDistanceAccumulates() async {
    let service = ActivityTrackingService()
    await service.start()

    // Two points ~111m apart (0.001 degrees latitude)
    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(30)
    )
    await service.addLocation(loc2)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 2)
    #expect(stats.distance > 50)
    #expect(stats.distance < 200)
}

@Test func activityTrackingElevationThreshold() async {
    let service = ActivityTrackingService()
    await service.start()

    // Point 1: 100m altitude
    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    // Point 2: 102m altitude (only +2m, below 3m threshold — should NOT count)
    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
        altitude: 102,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(30)
    )
    await service.addLocation(loc2)

    let stats2 = await service.currentStats()
    #expect(stats2.elevationGain == 0)

    // Point 3: 110m altitude (+8m from point 2, above threshold)
    let loc3 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.902, longitude: 10.7),
        altitude: 110,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(60)
    )
    await service.addLocation(loc3)

    let stats3 = await service.currentStats()
    #expect(stats3.elevationGain > 0)
}

@Test func activityTrackingElevationLoss() async {
    let service = ActivityTrackingService()
    await service.start()

    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 200,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    // Drop 20m
    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
        altitude: 180,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(30)
    )
    await service.addLocation(loc2)

    let stats = await service.currentStats()
    #expect(stats.elevationLoss > 0)
    #expect(stats.elevationGain == 0)
}

@Test func activityFinishAggregates() async {
    let service = ActivityTrackingService()
    await service.start()

    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.902, longitude: 10.7),
        altitude: 150,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(120)
    )
    await service.addLocation(loc2)

    let result = await service.finish()
    #expect(result.trackPoints.count == 2)
    #expect(result.distance > 100)
    #expect(result.elevationGain > 0)
    #expect(result.duration > 0)
    #expect(result.startedAt < result.endedAt)

    // Each track point should have [lon, lat, alt, timestamp]
    #expect(result.trackPoints[0].count == 4)
}

// MARK: - ActivityViewModel Formatting Tests

@Test @MainActor func formatDurationMinutesOnly() {
    let result = ActivityViewModel.formatDuration(125) // 2:05
    #expect(result == "2:05")
}

@Test @MainActor func formatDurationWithHours() {
    let result = ActivityViewModel.formatDuration(3725) // 1:02:05
    #expect(result == "1:02:05")
}

@Test @MainActor func formatDurationZero() {
    let result = ActivityViewModel.formatDuration(0)
    #expect(result == "0:00")
}
