@preconcurrency import ActivityKit
import CoreLocation
import Foundation
import OSLog
import SwiftUI

@MainActor
@Observable
final class NavigationViewModel {

    // MARK: - Public State

    var isActive = false
    var isPaused = false
    var gpsQuality: GPSQuality = .good
    var hasArrived = false
    var cameraMode: NavigationCameraMode = .courseUp
    var destination: CLLocationCoordinate2D?
    var compassBearing: Double = 0
    var compassDistance: Double = 0

    // MARK: - Private State

    /// Avstand til destinasjon ved oppstart — hindrer feilaktig "Fremme!"
    /// når brukeren starter nær destinasjonen (f.eks. retrace av rundtur).
    private var compassStartDistance: Double?
    private var lastProcessedTime: Date?
    private var isProcessingUpdate = false
    private var navigationActivityID: String?
    private var lastActivityUpdate: Date?

    private static let activityUpdateInterval: TimeInterval = 5.0

    /// Watchdog som slår GPS-kvaliteten til `.lost` hvis ingen posisjon
    /// kommer inn innen `gpsWatchdogTimeout`. `GPSQuality(accuracy:)` dekker
    /// bare unøyaktighet, ikke fravær av signal.
    private var gpsWatchdogTask: Task<Void, Never>?

    private static let arrivalThreshold: Double = 30
    private static let minUpdateInterval: TimeInterval = 1.0
    private static let gpsWatchdogTimeout: TimeInterval = 15

    // MARK: - Start Compass Navigation

    func startCompassNavigation(to dest: CLLocationCoordinate2D) {
        destination = dest
        isActive = true
        isPaused = false
        hasArrived = false
        compassStartDistance = nil
        HapticFeedback.prepare()
        restartGPSWatchdog()
        startLiveActivity()
    }

    // MARK: - Pause / Resume

    func pauseNavigation() {
        guard isActive else { return }
        isPaused = true
        cancelGPSWatchdog()
        updateLiveActivity()
    }

    func resumeNavigation() {
        guard isActive else { return }
        isPaused = false
        restartGPSWatchdog()
        updateLiveActivity()
    }

    // MARK: - Stop Navigation

    func stopNavigation() {
        cancelGPSWatchdog()
        endLiveActivity()
        isActive = false
        isPaused = false
        gpsQuality = .good
        hasArrived = false
        destination = nil
        compassBearing = 0
        compassDistance = 0
        compassStartDistance = nil
        lastProcessedTime = nil
        isProcessingUpdate = false
        lastActivityUpdate = nil
    }

    // MARK: - Process Location Update

    func processLocationUpdate(_ location: CLLocation) async {
        guard isActive, !isPaused, !isProcessingUpdate else { return }

        if let last = lastProcessedTime,
           Date().timeIntervalSince(last) < Self.minUpdateInterval {
            return
        }

        isProcessingUpdate = true
        defer {
            isProcessingUpdate = false
            lastProcessedTime = Date()
        }

        gpsQuality = GPSQuality(accuracy: location.horizontalAccuracy)
        restartGPSWatchdog()
        processCompassUpdate(location)
    }

    // MARK: - GPS Watchdog

    /// Avbryter en eventuell løpende watchdog og starter en ny nedtelling.
    /// Kalles hver gang en fersk posisjon behandles, samt ved start/resume.
    private func restartGPSWatchdog() {
        gpsWatchdogTask?.cancel()
        gpsWatchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.gpsWatchdogTimeout))
            guard !Task.isCancelled, let self else { return }
            self.gpsQuality = .lost
        }
    }

    private func cancelGPSWatchdog() {
        gpsWatchdogTask?.cancel()
        gpsWatchdogTask = nil
    }

    // MARK: - Compass Update

    private func processCompassUpdate(_ location: CLLocation) {
        guard let dest = destination else { return }

        compassBearing = Bearing.bearing(from: location.coordinate, to: dest)
        compassDistance = Haversine.distance(from: location.coordinate, to: dest)

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
            HapticFeedback.success()
        }

        updateLiveActivity()
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityKit.ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityKit.ActivityContent(state: currentActivityState(), staleDate: nil)
        do {
            let activity = try ActivityKit.Activity.request(
                attributes: NavigationActivityAttributes(),
                content: content
            )
            navigationActivityID = activity.id
        } catch {
            Logger.navigation.error("Live Activity start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateLiveActivity() {
        guard let id = navigationActivityID else { return }
        let now = Date()
        if let last = lastActivityUpdate,
           now.timeIntervalSince(last) < Self.activityUpdateInterval { return }
        lastActivityUpdate = now
        let content = ActivityKit.ActivityContent(state: currentActivityState(), staleDate: nil)
        Task {
            guard let activity = ActivityKit.Activity<NavigationActivityAttributes>.activities
                .first(where: { $0.id == id }) else { return }
            await activity.update(content)
        }
    }

    private func endLiveActivity() {
        guard let id = navigationActivityID else { return }
        navigationActivityID = nil
        let state = currentActivityState()
        Task {
            guard let activity = ActivityKit.Activity<NavigationActivityAttributes>.activities
                .first(where: { $0.id == id }) else { return }
            await activity.end(
                ActivityKit.ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private func currentActivityState() -> NavigationActivityAttributes.ContentState {
        NavigationActivityAttributes.ContentState(
            bearing: Int(compassBearing),
            cardinalDirection: cardinalDirection(for: compassBearing),
            distance: MeasurementService.formatDistance(compassDistance),
            isPaused: isPaused
        )
    }

    private func cardinalDirection(for degrees: Double) -> String {
        let n = ((degrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        switch n {
        case 337.5..<360, 0..<22.5: return "N"
        case 22.5..<67.5: return "N\u{00D8}"
        case 67.5..<112.5: return "\u{00D8}"
        case 112.5..<157.5: return "S\u{00D8}"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SV"
        case 247.5..<292.5: return "V"
        case 292.5..<337.5: return "NV"
        default: return ""
        }
    }

    // MARK: - Camera Mode

    func toggleCameraMode() {
        cameraMode = cameraMode == .northUp ? .courseUp : .northUp
    }
}
