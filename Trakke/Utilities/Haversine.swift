import Foundation
import CoreLocation

enum Haversine {
    private static let earthRadius = 6371000.0 // meters

    static func distance(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        let lat1 = c1.latitude * .pi / 180
        let lat2 = c2.latitude * .pi / 180
        let dLat = (c2.latitude - c1.latitude) * .pi / 180
        let dLon = (c2.longitude - c1.longitude) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    static func totalDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<coordinates.count {
            total += distance(from: coordinates[i - 1], to: coordinates[i])
        }
        return total
    }

    /// Overload for [[lon, lat]] coordinate arrays (used by Route model)
    static func totalDistance(coordinates: [[Double]]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<coordinates.count {
            guard coordinates[i - 1].count >= 2, coordinates[i].count >= 2 else { continue }
            let c1 = CLLocationCoordinate2D(latitude: coordinates[i - 1][1], longitude: coordinates[i - 1][0])
            let c2 = CLLocationCoordinate2D(latitude: coordinates[i][1], longitude: coordinates[i][0])
            total += distance(from: c1, to: c2)
        }
        return total
    }

    static func cumulativeDistances(coordinates: [CLLocationCoordinate2D]) -> [Double] {
        guard !coordinates.isEmpty else { return [] }
        var distances = [0.0]
        for i in 1..<coordinates.count {
            distances.append(distances[i - 1] + distance(from: coordinates[i - 1], to: coordinates[i]))
        }
        return distances
    }

    static func sampleCoordinates(
        _ coordinates: [CLLocationCoordinate2D],
        interval: Double = 100
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }

        var sampled = [coordinates[0]]
        var accumulated = 0.0

        for i in 1..<coordinates.count {
            accumulated += distance(from: coordinates[i - 1], to: coordinates[i])
            if accumulated >= interval {
                sampled.append(coordinates[i])
                accumulated = 0
            }
        }

        // Always include the last point
        if let last = coordinates.last, let sampledLast = sampled.last {
            if sampledLast.latitude != last.latitude || sampledLast.longitude != last.longitude {
                sampled.append(last)
            }
        }

        return sampled
    }
}
