import Foundation
import CoreLocation
import UIKit

@MainActor
@Observable
final class NavigationViewModel {

    // MARK: - Public State

    var isActive = false
    var mode: NavigationMode = .route
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var progress: NavigationProgress?
    var snapResult: SnapResult?
    var gpsQuality: GPSQuality = .good
    var isOffTrack = false
    var offTrackDistance: Double = 0
    var hasArrived = false
    var cameraMode: NavigationCameraMode = .northUp
    var destination: CLLocationCoordinate2D?
    var compassBearing: Double = 0
    var compassDistance: Double = 0
    var isComputingRoute = false
    var routeError: String?
    var instructions: [TurnInstruction] = []
    var nextInstruction: TurnInstruction?
    var routeSummary: String = ""

    // MARK: - Private State

    private let navigationService = NavigationService()
    private let routingService = RoutingService()
    private var elevationProfile: [ElevationPoint] = []
    private var cumulativeDistances: [Double] = []
    private var totalDistance: Double = 0
    private var lastSegmentIndex = 0
    private var consecutiveOffTrackReadings = 0
    private var lastDeviationAlertTime: Date?
    private var lastProcessedTime: Date?
    private var isProcessingUpdate = false
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    // Navigation update throttling: GPS updates arrive at ~1 Hz, but snap-to-route
    // and progress calculations are expensive. Updates are skipped if less than
    // minUpdateInterval has elapsed since the last processed update.
    // Off-track detection requires consecutiveReadingsRequired readings above
    // offTrackThreshold meters to avoid false positives from GPS jitter.
    private static let offTrackThreshold: Double = 50
    private static let minUpdateInterval: TimeInterval = 1.0
    private static let deviationAlertCooldown: TimeInterval = 30
    private static let consecutiveReadingsRequired = 3
    private static let arrivalThreshold: Double = 30

    // MARK: - Start Navigation (Computed Route via Valhalla)

    func startRouteNavigation(
        from origin: CLLocationCoordinate2D,
        to dest: CLLocationCoordinate2D
    ) async -> Bool {
        destination = dest
        isComputingRoute = true
        routeError = nil
        feedbackGenerator.prepare()

        do {
            let computedRoute = try await routingService.computeRoute(from: origin, to: dest)
            routeCoordinates = computedRoute.coordinates
            instructions = computedRoute.instructions
            routeSummary = computedRoute.summary
            totalDistance = computedRoute.distance
            cumulativeDistances = Haversine.cumulativeDistances(coordinates: routeCoordinates)

            mode = .route
            isActive = true
            isComputingRoute = false
            lastSegmentIndex = 0
            consecutiveOffTrackReadings = 0
            return true
        } catch {
            isComputingRoute = false
            routeError = error.localizedDescription
            return false
        }
    }

    // MARK: - Start Navigation (Follow Existing Route)

    func startFollowingRoute(
        route: Route,
        elevationProfile: [ElevationPoint] = []
    ) {
        // Convert Route coordinates [lon, lat] to CLLocationCoordinate2D
        routeCoordinates = route.coordinates.compactMap { coord in
            guard coord.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
        guard routeCoordinates.count >= 2 else { return }

        self.elevationProfile = elevationProfile
        totalDistance = route.distance ?? Haversine.totalDistance(coordinates: routeCoordinates)
        cumulativeDistances = Haversine.cumulativeDistances(coordinates: routeCoordinates)
        instructions = []
        routeSummary = route.name
        destination = routeCoordinates.last
        feedbackGenerator.prepare()

        mode = .route
        isActive = true
        lastSegmentIndex = 0
        consecutiveOffTrackReadings = 0
    }

    // MARK: - Start Compass Navigation

    func startCompassNavigation(to dest: CLLocationCoordinate2D) {
        destination = dest
        mode = .compass
        isActive = true
        routeCoordinates = []
        instructions = []
        feedbackGenerator.prepare()
    }

    // MARK: - Stop Navigation

    func stopNavigation() {
        isActive = false
        mode = .route
        routeCoordinates = []
        progress = nil
        snapResult = nil
        gpsQuality = .good
        isOffTrack = false
        offTrackDistance = 0
        hasArrived = false
        destination = nil
        compassBearing = 0
        compassDistance = 0
        isComputingRoute = false
        routeError = nil
        instructions = []
        nextInstruction = nil
        routeSummary = ""
        elevationProfile = []
        cumulativeDistances = []
        totalDistance = 0
        lastSegmentIndex = 0
        consecutiveOffTrackReadings = 0
        lastDeviationAlertTime = nil
        lastProcessedTime = nil
        isProcessingUpdate = false
    }

    // MARK: - Process Location Update

    func processLocationUpdate(_ location: CLLocation) async {
        guard isActive, !isProcessingUpdate else { return }

        // Throttle: skip updates that arrive faster than 1/sec
        if let last = lastProcessedTime,
           Date().timeIntervalSince(last) < Self.minUpdateInterval {
            return
        }

        isProcessingUpdate = true
        defer {
            isProcessingUpdate = false
            lastProcessedTime = Date()
        }

        // Compute GPS quality before the mode-specific work, but defer the
        // @Observable assignment to after the await so all property changes
        // happen in a single synchronous block (avoids double SwiftUI update).
        let quality = GPSQuality(accuracy: location.horizontalAccuracy)

        switch mode {
        case .route:
            await processRouteUpdate(location, quality: quality)
        case .compass:
            gpsQuality = quality
            processCompassUpdate(location)
        }
    }

    // MARK: - Route Mode Processing

    private func processRouteUpdate(_ location: CLLocation, quality: GPSQuality) async {
        guard routeCoordinates.count >= 2 else { return }

        // Single actor hop for all navigation computations
        guard let result = await navigationService.computeProgress(
            location: location.coordinate,
            routeCoordinates: routeCoordinates,
            cumulativeDistances: cumulativeDistances,
            elevationProfile: elevationProfile,
            totalDistance: totalDistance,
            fromIndex: lastSegmentIndex
        ) else { return }

        // All @Observable property changes below happen synchronously (after
        // the await) so SwiftUI coalesces them into a single update cycle.
        gpsQuality = quality

        let snap = result.snap
        let remaining = result.remaining

        snapResult = snap
        lastSegmentIndex = snap.segmentIndex

        let traveled = totalDistance - remaining
        let fraction = totalDistance > 0 ? traveled / totalDistance : 0

        progress = NavigationProgress(
            distanceRemaining: remaining,
            distanceTraveled: traveled,
            totalDistance: totalDistance,
            elevationGainRemaining: result.gain,
            elevationLossRemaining: result.loss,
            estimatedTimeRemaining: result.time,
            currentSegmentIndex: snap.segmentIndex,
            fractionCompleted: min(max(fraction, 0), 1)
        )

        // Update next instruction
        updateNextInstruction(atDistance: snap.alongTrackDistance)

        // Deviation detection
        offTrackDistance = snap.crossTrackDistance
        if snap.crossTrackDistance > Self.offTrackThreshold && gpsQuality != .lost {
            consecutiveOffTrackReadings += 1
            if consecutiveOffTrackReadings >= Self.consecutiveReadingsRequired {
                triggerDeviationAlert()
            }
        } else {
            consecutiveOffTrackReadings = 0
            if isOffTrack && snap.crossTrackDistance <= Self.offTrackThreshold {
                isOffTrack = false
            }
        }

        // Arrival detection
        if !hasArrived && remaining < Self.arrivalThreshold {
            hasArrived = true
            triggerArrivalFeedback()
        }
    }

    // MARK: - Compass Mode Processing

    private func processCompassUpdate(_ location: CLLocation) {
        guard let dest = destination else { return }

        compassBearing = Bearing.bearing(from: location.coordinate, to: dest)
        compassDistance = Haversine.distance(from: location.coordinate, to: dest)

        if !hasArrived && compassDistance < Self.arrivalThreshold {
            hasArrived = true
            triggerArrivalFeedback()
        }
    }

    // MARK: - Turn Instructions

    private func updateNextInstruction(atDistance: Double) {
        guard !instructions.isEmpty else { return }

        // Find the next instruction ahead of our current position
        for instruction in instructions where instruction.distance > atDistance {
            nextInstruction = instruction
            return
        }

        // If we've passed all instructions, show the last one (destination)
        nextInstruction = instructions.last
    }

    // MARK: - Reverse Route

    func reverseRoute() {
        guard mode == .route, !routeCoordinates.isEmpty else { return }

        routeCoordinates.reverse()
        cumulativeDistances = Haversine.cumulativeDistances(coordinates: routeCoordinates)

        // Recompute elevation profile distances for reversed direction
        if !elevationProfile.isEmpty {
            let maxDist = elevationProfile.last?.distance ?? totalDistance
            elevationProfile = elevationProfile.reversed().map { point in
                ElevationPoint(
                    coordinate: point.coordinate,
                    elevation: point.elevation,
                    distance: maxDist - point.distance
                )
            }
        }

        instructions = [] // Valhalla instructions don't apply to reversed route
        nextInstruction = nil
        destination = routeCoordinates.last
        lastSegmentIndex = 0
        consecutiveOffTrackReadings = 0
        isOffTrack = false
        hasArrived = false
    }

    // MARK: - Switch Mode

    func switchToCompass() {
        guard let dest = destination else { return }
        mode = .compass
        routeCoordinates = []
        instructions = []
        nextInstruction = nil
        progress = nil
        snapResult = nil
        isOffTrack = false
        consecutiveOffTrackReadings = 0
        destination = dest
    }

    func toggleCameraMode() {
        cameraMode = cameraMode == .northUp ? .courseUp : .northUp
    }

    func dismissDeviation() {
        isOffTrack = false
        lastDeviationAlertTime = Date()
    }

    // MARK: - Haptic Feedback

    private func triggerDeviationAlert() {
        let now = Date()
        if let lastAlert = lastDeviationAlertTime,
           now.timeIntervalSince(lastAlert) < Self.deviationAlertCooldown {
            return
        }

        isOffTrack = true
        lastDeviationAlertTime = now
        feedbackGenerator.notificationOccurred(.warning)
    }

    private func triggerArrivalFeedback() {
        feedbackGenerator.notificationOccurred(.success)
    }
}
