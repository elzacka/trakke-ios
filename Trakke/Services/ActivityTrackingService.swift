import Foundation
import CoreLocation

struct TrackPoint: Sendable {
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
}

protocol ActivityTracking: Sendable {
    func start() async
    func addLocation(_ location: CLLocation) async
    func finish() async -> ActivityResult
    func currentStats() async -> ActivityStats
}

actor ActivityTrackingService: ActivityTracking {
    private var trackPoints: [TrackPoint] = []
    private var startTime: Date?
    private var totalDistance: Double = 0
    private var elevationGain: Double = 0
    private var elevationLoss: Double = 0

    /// Minimum horizontal accuracy to accept a point (meters)
    private static let maxAccuracy: Double = 50
    /// Minimum distance between recorded points (meters)
    private static let minPointDistance: Double = 10
    /// Minimum elevation change to count as gain/loss (meters)
    private static let elevationThreshold: Double = 3

    func start() {
        trackPoints = []
        totalDistance = 0
        elevationGain = 0
        elevationLoss = 0
        startTime = Date()
    }

    func addLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= Self.maxAccuracy,
              location.coordinate.latitude.isFinite,
              location.coordinate.longitude.isFinite else {
            return
        }

        let point = TrackPoint(
            coordinate: location.coordinate,
            altitude: location.verticalAccuracy >= 0 ? location.altitude : 0,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy
        )

        if let lastPoint = trackPoints.last {
            let dist = Haversine.distance(from: lastPoint.coordinate, to: point.coordinate)
            guard dist >= Self.minPointDistance else { return }

            totalDistance += dist

            if lastPoint.altitude > 0, point.altitude > 0 {
                let elevDiff = point.altitude - lastPoint.altitude
                if elevDiff > Self.elevationThreshold {
                    elevationGain += elevDiff
                } else if elevDiff < -Self.elevationThreshold {
                    elevationLoss += abs(elevDiff)
                }
            }
        }

        trackPoints.append(point)
    }

    func finish() -> ActivityResult {
        let endTime = Date()
        let duration = startTime.map { endTime.timeIntervalSince($0) } ?? 0

        let encodedPoints = trackPoints.map { point -> [Double] in
            [point.coordinate.longitude, point.coordinate.latitude, point.altitude, point.timestamp.timeIntervalSince1970]
        }

        return ActivityResult(
            trackPoints: encodedPoints,
            distance: totalDistance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            duration: duration,
            startedAt: startTime ?? endTime,
            endedAt: endTime
        )
    }

    func currentStats() -> ActivityStats {
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        return ActivityStats(
            pointCount: trackPoints.count,
            distance: totalDistance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            duration: duration
        )
    }
}

struct ActivityResult: Sendable {
    let trackPoints: [[Double]]
    let distance: Double
    let elevationGain: Double
    let elevationLoss: Double
    let duration: TimeInterval
    let startedAt: Date
    let endedAt: Date
}

struct ActivityStats: Sendable {
    let pointCount: Int
    let distance: Double
    let elevationGain: Double
    let elevationLoss: Double
    let duration: TimeInterval
}
