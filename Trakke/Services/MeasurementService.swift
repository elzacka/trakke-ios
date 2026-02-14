import Foundation
import CoreLocation

enum MeasurementService {
    // MARK: - Distance

    static func distance(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        Haversine.distance(from: c1, to: c2)
    }

    static func polylineDistance(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        Haversine.totalDistance(coordinates: coordinates)
    }

    // MARK: - Area (Spherical Polygon)

    static func polygonArea(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 3 else { return 0 }

        let earthRadius = 6371000.0
        var coords = coordinates

        // Close polygon if needed
        if let first = coords.first, let last = coords.last,
           first.latitude != last.latitude || first.longitude != last.longitude {
            coords.append(first)
        }

        var area = 0.0
        for i in 0..<(coords.count - 1) {
            let lon1 = coords[i].longitude * .pi / 180
            let lon2 = coords[i + 1].longitude * .pi / 180
            let lat1 = coords[i].latitude * .pi / 180
            let lat2 = coords[i + 1].latitude * .pi / 180

            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        return abs(area * earthRadius * earthRadius / 2)
    }

    // MARK: - Formatting

    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    static func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 10_000 {
            return String(format: "%.2f km\u{00B2}", squareMeters / 1_000_000)
        }
        return String(format: "%.0f m\u{00B2}", squareMeters)
    }
}
