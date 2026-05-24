import Foundation
import CoreLocation
import SwiftUI

@MainActor
@Observable
final class NavigationViewModel {

    // MARK: - Public State

    var isActive = false
    var isPaused = false
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
    /// Avstand til destinasjon ved start av kompass-navigasjon — brukes til
    /// å unngå feilaktig "Fremme!" når brukeren starter nær destinasjonen
    /// (f.eks. ved retrace av en rundtur som ender der den startet).
    private var compassStartDistance: Double?
    var isComputingRoute = false
    var routeError: String?
    var instructions: [TurnInstruction] = []
    var nextInstruction: TurnInstruction?
    var routeSummary: String = ""

    // MARK: - Private State

    private let navigationService = NavigationService()
    private let routingService: RoutingService
    private var routeComputationTask: Task<Bool, Never>?

    init(routingService: RoutingService = RoutingService()) {
        self.routingService = routingService
    }
    private var elevationProfile: [ElevationPoint] = []
    private var cumulativeDistances: [Double] = []
    private(set) var totalDistance: Double = 0
    private var lastSegmentIndex = 0
    private var consecutiveOffTrackReadings = 0
    private var lastDeviationAlertTime: Date?
    private var lastProcessedTime: Date?
    private var isProcessingUpdate = false
    private var lastLocation: CLLocation?
    private var offTrackSince: Date?
    private var nextInstructionIndex: Int?
    private var pendingTurnHaptics: Set<Int> = []

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
    // Pre-turn haptic thresholds: heavier nudge close in, softer further out.
    // Only fired for real turns (skip departure / destination / continuations).
    private static let preTurnHapticDistances: [Int] = [50, 15]
    // How long the user must remain off-track before we offer to recompute.
    private static let rerouteEligibleAfter: TimeInterval = 60

    // MARK: - Start Navigation (Computed Route via Valhalla)

    func startRouteNavigation(
        from origin: CLLocationCoordinate2D,
        to dest: CLLocationCoordinate2D
    ) async -> Bool {
        routeComputationTask?.cancel()
        destination = dest
        isComputingRoute = true
        isPaused = false  // Defensiv: en tidligere økt kan ha etterlatt true
        routeError = nil
        HapticFeedback.prepare()

        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            do {
                let computedRoute = try await self.routingService.computeRoute(from: origin, to: dest)
                guard !Task.isCancelled else {
                    self.isComputingRoute = false
                    return false
                }
                self.routeCoordinates = computedRoute.coordinates
                self.instructions = computedRoute.instructions
                self.routeSummary = computedRoute.summary
                self.totalDistance = computedRoute.distance
                self.cumulativeDistances = Haversine.cumulativeDistances(coordinates: self.routeCoordinates)

                self.mode = .route
                self.isActive = true
                self.isComputingRoute = false
                self.hasArrived = false
                self.lastSegmentIndex = 0
                self.consecutiveOffTrackReadings = 0
                return true
            } catch {
                self.isComputingRoute = false
                guard !Task.isCancelled else { return false }
                self.routeError = error.localizedDescription
                return false
            }
        }
        routeComputationTask = task

        // Sikkerhetsnett: tving feilstatus etter 18s hvis URLSession-timeout
        // ikke har gitt utslag (f.eks. når waitsForConnectivity holder
        // forespørselen i kø uten å avslutte).
        let timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(18))
            guard let self, self.isComputingRoute else { return }
            self.routeComputationTask?.cancel()
            self.isComputingRoute = false
            if self.routeError == nil {
                self.routeError = String(localized: "navigation.routeErrorTimeout")
            }
        }
        defer { timeoutTask.cancel() }

        return await task.value
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
        HapticFeedback.prepare()

        mode = .route
        isActive = true
        isPaused = false  // Defensiv: en tidligere økt kan ha etterlatt true
        hasArrived = false
        lastSegmentIndex = 0
        consecutiveOffTrackReadings = 0
    }

    // MARK: - Start Compass Navigation

    func startCompassNavigation(to dest: CLLocationCoordinate2D) {
        routeComputationTask?.cancel()
        routeComputationTask = nil
        destination = dest
        mode = .compass
        isActive = true
        isPaused = false  // Defensiv: en tidligere økt kan ha etterlatt true
        hasArrived = false
        routeCoordinates = []
        instructions = []
        compassStartDistance = nil  // Settes ved første GPS-oppdatering
        HapticFeedback.prepare()
    }

    // MARK: - Pause / Resume

    /// Pauser navigasjon visuelt. Stats fryses og GPS-oppdateringer ignoreres,
    /// men hele rute-tilstanden beholdes så bruker kan fortsette med resume.
    func pauseNavigation() {
        guard isActive else { return }
        isPaused = true
    }

    func resumeNavigation() {
        guard isActive else { return }
        isPaused = false
    }

    // MARK: - Stop Navigation

    func stopNavigation() {
        routeComputationTask?.cancel()
        routeComputationTask = nil
        isActive = false
        isPaused = false
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
        lastLocation = nil
        offTrackSince = nil
        nextInstructionIndex = nil
        pendingTurnHaptics = []
    }

    /// True after `Self.rerouteEligibleAfter` seconds of confirmed off-track.
    /// Drives the "Beregn rute på nytt" action in DeviationChipView.
    var canReroute: Bool {
        guard let since = offTrackSince else { return false }
        return Date.now.timeIntervalSince(since) >= Self.rerouteEligibleAfter
    }

    // MARK: - Process Location Update

    func processLocationUpdate(_ location: CLLocation) async {
        guard isActive, !isPaused, !isProcessingUpdate else { return }

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

        lastLocation = location

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

        // Mode may have changed while awaiting the actor hop
        guard mode == .route else { return }

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
                if offTrackSince == nil {
                    offTrackSince = Date()
                }
                triggerDeviationAlert()
            }
        } else {
            consecutiveOffTrackReadings = 0
            if snap.crossTrackDistance <= Self.offTrackThreshold {
                offTrackSince = nil
                if isOffTrack {
                    isOffTrack = false
                }
            }
        }

        // Arrival detection — krev at brukeren faktisk har beveget seg
        // langs ruten. Forhindrer falsk "Fremme!" når GPS-posisjon snapper
        // nær sluttpunktet ved oppstart (f.eks. for en sløyfe-aktivitet).
        let minTraveledForArrival = min(50.0, totalDistance * 0.1)
        if !hasArrived
            && remaining < Self.arrivalThreshold
            && traveled > minTraveledForArrival {
            hasArrived = true
            triggerArrivalFeedback()
        }
    }

    // MARK: - Compass Mode Processing

    private func processCompassUpdate(_ location: CLLocation) {
        guard let dest = destination else { return }

        compassBearing = Bearing.bearing(from: location.coordinate, to: dest)
        compassDistance = Haversine.distance(from: location.coordinate, to: dest)

        // Sett startdistanse ved første GPS-fix. Vi tillater ikke "Fremme!"
        // før brukeren faktisk har beveget seg vekk fra start og nærmer seg
        // destinasjonen igjen — uten dette vil retrace av en rundtur som
        // ender nær start utløse arrival umiddelbart.
        if compassStartDistance == nil {
            compassStartDistance = compassDistance
        }

        guard let startDistance = compassStartDistance else { return }
        let minStartDistance = Self.arrivalThreshold * 2  // 60m
        let hasMovedMeaningfully = startDistance > minStartDistance

        if !hasArrived
            && compassDistance < Self.arrivalThreshold
            && hasMovedMeaningfully {
            hasArrived = true
            triggerArrivalFeedback()
        }
    }

    // MARK: - Turn Instructions

    private func updateNextInstruction(atDistance: Double) {
        guard !instructions.isEmpty else { return }

        // Find the next instruction ahead of our current position
        var foundIndex: Int?
        for (i, instruction) in instructions.enumerated() where instruction.distance > atDistance {
            foundIndex = i
            break
        }
        let chosenIndex = foundIndex ?? instructions.count - 1

        if chosenIndex != nextInstructionIndex {
            nextInstructionIndex = chosenIndex
            // Reset haptic thresholds for the new turn — but only for real turns.
            // Departure / destination / continuations don't need pre-warning.
            let isHapticRelevant: Bool
            switch instructions[chosenIndex].type {
            case .right, .sharpRight, .slightRight,
                 .left, .sharpLeft, .slightLeft,
                 .uTurn:
                isHapticRelevant = true
            case .straight, .depart, .destination, .ferry, .other:
                isHapticRelevant = false
            }
            pendingTurnHaptics = isHapticRelevant ? Set(Self.preTurnHapticDistances) : []
        }

        let instruction = instructions[chosenIndex]
        nextInstruction = instruction

        let distToTurn = instruction.distance - atDistance
        // Fire each threshold once. Sort descending so 50 m fires before 15 m
        // if a single update jumps both (rare but possible after long throttle).
        for threshold in pendingTurnHaptics.sorted(by: >) where distToTurn <= Double(threshold) {
            if threshold <= 15 {
                HapticFeedback.nudge()
            } else {
                HapticFeedback.tap()
            }
            pendingTurnHaptics.remove(threshold)
        }
    }

    // MARK: - Reverse Route

    /// Reverses the active route. Uses Valhalla to compute a real route from the
    /// user's current position back to the original starting point, so turn-by-turn
    /// guidance and elevation are correct. Falls back to a polyline reverse if the
    /// routing service is unreachable (offline).
    func reverseRoute() async -> Bool {
        guard mode == .route, !routeCoordinates.isEmpty else { return false }
        let originalOrigin = routeCoordinates.first
        guard let origin = originalOrigin else { return false }

        if let currentLoc = lastLocation {
            isComputingRoute = true
            defer { isComputingRoute = false }
            do {
                let newRoute = try await routingService.computeRoute(
                    from: currentLoc.coordinate,
                    to: origin
                )
                applyRoute(newRoute)
                destination = origin
                return true
            } catch {
                // Network failure — fall through to polyline-reverse fallback
                routeError = error.localizedDescription
            }
        }

        // Fallback: simple polyline reverse without Valhalla turn instructions.
        routeCoordinates.reverse()
        cumulativeDistances = Haversine.cumulativeDistances(coordinates: routeCoordinates)
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
        instructions = []
        nextInstruction = nil
        nextInstructionIndex = nil
        pendingTurnHaptics = []
        destination = routeCoordinates.last
        lastSegmentIndex = 0
        consecutiveOffTrackReadings = 0
        isOffTrack = false
        offTrackSince = nil
        hasArrived = false
        return true
    }

    // MARK: - Reroute (off-track recovery)

    /// Recomputes the route from the user's current position to the existing
    /// destination. Call when `canReroute == true`.
    func requestReroute() async -> Bool {
        guard mode == .route,
              let dest = destination,
              let currentLoc = lastLocation else { return false }

        isComputingRoute = true
        defer { isComputingRoute = false }

        do {
            let newRoute = try await routingService.computeRoute(
                from: currentLoc.coordinate,
                to: dest
            )
            applyRoute(newRoute)
            return true
        } catch {
            routeError = error.localizedDescription
            return false
        }
    }

    private func applyRoute(_ route: ComputedRoute) {
        routeCoordinates = route.coordinates
        instructions = route.instructions
        routeSummary = route.summary
        totalDistance = route.distance
        cumulativeDistances = Haversine.cumulativeDistances(coordinates: routeCoordinates)
        elevationProfile = []
        nextInstruction = nil
        nextInstructionIndex = nil
        pendingTurnHaptics = []
        lastSegmentIndex = 0
        consecutiveOffTrackReadings = 0
        isOffTrack = false
        offTrackSince = nil
        hasArrived = false
    }

    // MARK: - Switch Mode

    func switchToCompass() {
        guard let dest = destination else { return }
        routeComputationTask?.cancel()
        routeComputationTask = nil
        isComputingRoute = false
        mode = .compass
        routeCoordinates = []
        instructions = []
        nextInstruction = nil
        progress = nil
        snapResult = nil
        isOffTrack = false
        hasArrived = false
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
        HapticFeedback.warning()
    }

    private func triggerArrivalFeedback() {
        HapticFeedback.success()
    }
}
