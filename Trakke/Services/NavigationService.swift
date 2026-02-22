import Foundation
import CoreLocation

actor NavigationService {

    // MARK: - Combined Progress Computation

    /// Computes all navigation progress in a single actor hop to minimize context switches.
    func computeProgress(
        location: CLLocationCoordinate2D,
        routeCoordinates: [CLLocationCoordinate2D],
        cumulativeDistances: [Double],
        elevationProfile: [ElevationPoint],
        totalDistance: Double,
        fromIndex: Int
    ) -> (snap: SnapResult, remaining: Double, gain: Double, loss: Double, time: TimeInterval)? {
        guard let snap = snapToTrack(
            location: location,
            routeCoordinates: routeCoordinates,
            cumulativeDistances: cumulativeDistances,
            fromIndex: fromIndex
        ) else { return nil }

        let remaining = remainingDistance(
            fromIndex: snap.segmentIndex,
            snappedCoordinate: snap.snappedCoordinate,
            routeCoordinates: routeCoordinates
        )

        let (gain, loss) = remainingElevation(
            fromAlongTrackDistance: snap.alongTrackDistance,
            elevationProfile: elevationProfile
        )

        let time = estimatedTime(
            remainingDistance: remaining,
            remainingGain: gain
        )

        return (snap, remaining, gain, loss, time)
    }

    // MARK: - Snap to Track

    /// Find the nearest point on a route polyline to the user's location.
    /// Uses a search window around `fromIndex` for performance on long routes.
    func snapToTrack(
        location: CLLocationCoordinate2D,
        routeCoordinates: [CLLocationCoordinate2D],
        cumulativeDistances: [Double],
        fromIndex: Int = 0
    ) -> SnapResult? {
        guard routeCoordinates.count >= 2 else { return nil }

        // Search window: +/- 50 segments from last known position, or full route
        let windowSize = 50
        let searchStart = max(0, fromIndex - windowSize)
        let searchEnd = min(routeCoordinates.count - 1, fromIndex + windowSize)

        var bestDistance = Double.greatestFiniteMagnitude
        var bestIndex = 0
        var bestCoordinate = routeCoordinates[0]

        for i in searchStart..<searchEnd {
            let (snapped, distance) = Bearing.closestPointOnSegment(
                point: location,
                segmentStart: routeCoordinates[i],
                segmentEnd: routeCoordinates[i + 1]
            )

            if distance < bestDistance {
                bestDistance = distance
                bestIndex = i
                bestCoordinate = snapped
            }
        }

        // If the window search didn't find a close match (>200m), search the full route
        if bestDistance > 200 && (searchStart > 0 || searchEnd < routeCoordinates.count - 1) {
            for i in 0..<routeCoordinates.count - 1 where i < searchStart || i >= searchEnd {
                let (snapped, distance) = Bearing.closestPointOnSegment(
                    point: location,
                    segmentStart: routeCoordinates[i],
                    segmentEnd: routeCoordinates[i + 1]
                )

                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = i
                    bestCoordinate = snapped
                }
            }
        }

        // Calculate along-track distance to the snapped point
        let distanceToSegmentStart = cumulativeDistances[bestIndex]
        let distanceWithinSegment = Haversine.distance(
            from: routeCoordinates[bestIndex],
            to: bestCoordinate
        )
        let alongTrackDist = distanceToSegmentStart + distanceWithinSegment

        // Bearing of the route at the snap point
        let routeBearing = Bearing.bearing(
            from: routeCoordinates[bestIndex],
            to: routeCoordinates[bestIndex + 1]
        )

        return SnapResult(
            segmentIndex: bestIndex,
            snappedCoordinate: bestCoordinate,
            crossTrackDistance: bestDistance,
            alongTrackDistance: alongTrackDist,
            routeBearing: routeBearing
        )
    }

    // MARK: - Remaining Distance

    func remainingDistance(
        fromIndex: Int,
        snappedCoordinate: CLLocationCoordinate2D,
        routeCoordinates: [CLLocationCoordinate2D]
    ) -> Double {
        guard fromIndex < routeCoordinates.count - 1 else { return 0 }

        // Distance from snapped point to next vertex
        let toNextVertex = Haversine.distance(
            from: snappedCoordinate,
            to: routeCoordinates[fromIndex + 1]
        )

        // Sum remaining full segments
        var remaining = toNextVertex
        for i in (fromIndex + 1)..<(routeCoordinates.count - 1) {
            remaining += Haversine.distance(
                from: routeCoordinates[i],
                to: routeCoordinates[i + 1]
            )
        }

        return remaining
    }

    // MARK: - Remaining Elevation

    func remainingElevation(
        fromAlongTrackDistance: Double,
        elevationProfile: [ElevationPoint]
    ) -> (gain: Double, loss: Double) {
        guard elevationProfile.count >= 2 else { return (0, 0) }

        // Find the first elevation point ahead of our position
        var startIndex = 0
        for (i, point) in elevationProfile.enumerated() {
            if point.distance >= fromAlongTrackDistance {
                startIndex = i
                break
            }
            startIndex = i
        }

        var gain = 0.0
        var loss = 0.0

        for i in startIndex..<(elevationProfile.count - 1) {
            let diff = elevationProfile[i + 1].elevation - elevationProfile[i].elevation
            if diff > 0 { gain += diff }
            else { loss += abs(diff) }
        }

        return (gain, loss)
    }

    // MARK: - Estimated Time (Naismith's Rule)

    /// Estimates hiking time using Naismith's rule:
    /// 5 km/h on flat ground + 1 minute per 10m of ascent.
    func estimatedTime(
        remainingDistance: Double,
        remainingGain: Double
    ) -> TimeInterval {
        let flatTime = remainingDistance / (5000.0 / 3600.0) // seconds at 5 km/h
        let climbTime = (remainingGain / 10.0) * 60.0       // 1 min per 10m gain
        return flatTime + climbTime
    }

}
