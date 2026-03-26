import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: String
    var name: String
    /// GPS track as [[longitude, latitude, altitude, timestamp]] arrays
    var trackPoints: [[Double]]
    var distance: Double
    var elevationGain: Double
    var elevationLoss: Double
    var duration: TimeInterval
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date

    init(
        name: String,
        trackPoints: [[Double]] = [],
        distance: Double = 0,
        elevationGain: Double = 0,
        elevationLoss: Double = 0,
        duration: TimeInterval = 0,
        startedAt: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.trackPoints = trackPoints
        self.distance = distance
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.duration = duration
        self.startedAt = startedAt
        self.createdAt = Date()
    }

    /// Coordinates as CLLocationCoordinate2D-compatible [[lon, lat]] (same format as Route)
    var coordinates: [[Double]] {
        trackPoints.map { point in
            guard point.count >= 2 else { return [0, 0] }
            return [point[0], point[1]]
        }
    }

    /// Altitudes extracted from track points
    var altitudes: [Double] {
        trackPoints.compactMap { point in
            guard point.count >= 3 else { return nil }
            return point[2]
        }
    }
}
