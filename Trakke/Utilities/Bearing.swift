import Foundation
import CoreLocation

enum Bearing {
    private static let earthRadius = 6371000.0 // meters

    /// Initial bearing from one coordinate to another (degrees 0-360).
    static func bearing(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        let lat1 = c1.latitude * .pi / 180
        let lat2 = c2.latitude * .pi / 180
        let dLon = (c2.longitude - c1.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let theta = atan2(y, x)

        return (theta * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Cross-track distance: perpendicular distance from a point to the great-circle
    /// path defined by lineStart and lineEnd. Returns positive meters.
    static func crossTrackDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let d13 = Haversine.distance(from: lineStart, to: point) / earthRadius
        let theta13 = bearing(from: lineStart, to: point) * .pi / 180
        let theta12 = bearing(from: lineStart, to: lineEnd) * .pi / 180

        let dxt = asin(sin(d13) * sin(theta13 - theta12))
        return abs(dxt * earthRadius)
    }

    /// Along-track distance: distance along the great-circle path from lineStart
    /// to the closest point on that path to the given point. Can be negative if
    /// the closest point is before lineStart.
    static func alongTrackDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let d13 = Haversine.distance(from: lineStart, to: point) / earthRadius
        let dxt = crossTrackDistance(point: point, lineStart: lineStart, lineEnd: lineEnd) / earthRadius

        let ratio = min(1.0, max(-1.0, cos(d13) / cos(dxt)))
        let dat = acos(ratio)
        // Determine sign based on whether point is "ahead" of lineStart
        let theta13 = bearing(from: lineStart, to: point) * .pi / 180
        let theta12 = bearing(from: lineStart, to: lineEnd) * .pi / 180
        let angleDiff = abs(theta13 - theta12)

        if angleDiff > .pi / 2 && angleDiff < 3 * .pi / 2 {
            return -dat * earthRadius
        }
        return dat * earthRadius
    }

    /// Find the closest point on a line segment to a given point.
    /// Returns the snapped coordinate and the distance from the point to that coordinate.
    static func closestPointOnSegment(
        point: CLLocationCoordinate2D,
        segmentStart: CLLocationCoordinate2D,
        segmentEnd: CLLocationCoordinate2D
    ) -> (coordinate: CLLocationCoordinate2D, distance: Double) {
        let segmentLength = Haversine.distance(from: segmentStart, to: segmentEnd)

        guard segmentLength > 0.1 else {
            // Degenerate segment
            let d = Haversine.distance(from: segmentStart, to: point)
            return (segmentStart, d)
        }

        let along = alongTrackDistance(point: point, lineStart: segmentStart, lineEnd: segmentEnd)
        let fraction = along / segmentLength

        if fraction <= 0 {
            let d = Haversine.distance(from: segmentStart, to: point)
            return (segmentStart, d)
        } else if fraction >= 1 {
            let d = Haversine.distance(from: segmentEnd, to: point)
            return (segmentEnd, d)
        }

        // Interpolate along the segment
        let coord = interpolate(from: segmentStart, to: segmentEnd, fraction: fraction)
        let d = Haversine.distance(from: coord, to: point)
        return (coord, d)
    }

    /// Interpolate between two coordinates by a fraction (0.0 = start, 1.0 = end).
    static func interpolate(
        from c1: CLLocationCoordinate2D,
        to c2: CLLocationCoordinate2D,
        fraction f: Double
    ) -> CLLocationCoordinate2D {
        let lat1 = c1.latitude * .pi / 180
        let lon1 = c1.longitude * .pi / 180
        let lat2 = c2.latitude * .pi / 180
        let lon2 = c2.longitude * .pi / 180

        let d = Haversine.distance(from: c1, to: c2) / earthRadius
        guard d > 1e-10 else { return c1 }

        let a = sin((1 - f) * d) / sin(d)
        let b = sin(f * d) / sin(d)

        let x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2)
        let y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2)
        let z = a * sin(lat1) + b * sin(lat2)

        let lat = atan2(z, sqrt(x * x + y * y))
        let lon = atan2(y, x)

        return CLLocationCoordinate2D(
            latitude: lat * 180 / .pi,
            longitude: lon * 180 / .pi
        )
    }
}
