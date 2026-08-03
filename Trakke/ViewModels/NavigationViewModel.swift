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

    /// Største observerte avstand til destinasjonen i økten – hindrer
    /// feilaktig "Fremme!" når brukeren starter nær destinasjonen (f.eks.
    /// retrace av rundtur). Ankomst krever at brukeren enten har vært lengre
    /// unna enn 2x terskelen, eller har nærmet seg minst én terskel – slik
    /// fungerer ankomst også for mål brukeren starter 30-60 m fra.
    private var maxObservedDistance: Double = 0
    private var lastProcessedTime: Date?
    private var isProcessingUpdate = false
    private var navigationActivityID: String?
    private var lastActivityUpdate: Date?

    private static let activityUpdateInterval: TimeInterval = 5.0
    /// Romslig stale-frist: mister enheten GPS-fiks en stund (skog, juv,
    /// innendørs) skal låseskjerm/Dynamic Island vise siste kjente verdi i
    /// stedet for å nedtones etter ett minutt.
    private static let activityStaleInterval: TimeInterval = 600

    /// Watchdog som slår GPS-kvaliteten til `.lost` hvis ingen posisjon
    /// kommer inn innen `gpsWatchdogTimeout`. `GPSQuality(accuracy:)` dekker
    /// bare unøyaktighet, ikke fravær av signal.
    private var gpsWatchdogTask: Task<Void, Never>?

    private static let arrivalThreshold: Double = 30
    private static let minUpdateInterval: TimeInterval = 1.0
    /// Instansvariabel (ikke static) slik at tester kan korte den ned uten å
    /// påvirke parallelle tester.
    var gpsWatchdogTimeout: TimeInterval = 15

    // MARK: - Start Compass Navigation

    func startCompassNavigation(to dest: CLLocationCoordinate2D) {
        destination = dest
        isActive = true
        isPaused = false
        hasArrived = false
        maxObservedDistance = 0
        HapticFeedback.prepare()
        restartGPSWatchdog()
        startLiveActivity()
    }

    // MARK: - Pause / Resume

    func pauseNavigation() {
        guard isActive else { return }
        isPaused = true
        cancelGPSWatchdog()
        updateLiveActivity(force: true)
    }

    func resumeNavigation() {
        guard isActive else { return }
        isPaused = false
        restartGPSWatchdog()
        updateLiveActivity(force: true)
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
        maxObservedDistance = 0
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
        let timeout = gpsWatchdogTimeout
        gpsWatchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
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
        maxObservedDistance = max(maxObservedDistance, compassDistance)

        let minStartDistance = Self.arrivalThreshold * 2  // 60m
        let hasMovedMeaningfully = maxObservedDistance > minStartDistance
            || maxObservedDistance - compassDistance > Self.arrivalThreshold

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
        guard ActivityKit.ActivityAuthorizationInfo().areActivitiesEnabled else {
            // Skjer når brukeren har slått av Live Activities for appen
            // (Innstillinger → Tråkke → Live-aktiviteter) – synlig i Console.
            Logger.navigation.warning("Live Activity: aktiviteter er slått av for appen")
            return
        }
        navigationActivityID = nil
        Task { [weak self] in
            // Gamle aktiviteter (forrige økt eller re-målretting) MÅ avsluttes
            // i samme task som den nye opprettes – en frittstående opprydding
            // kjører etter Activity.request og avliver den nye aktiviteten.
            for activity in ActivityKit.Activity<NavigationActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard let self, self.isActive else { return }
            let content = ActivityKit.ActivityContent(
                state: self.currentActivityState(),
                staleDate: Date().addingTimeInterval(Self.activityStaleInterval)
            )
            do {
                let activity = try ActivityKit.Activity.request(
                    attributes: NavigationActivityAttributes(),
                    content: content
                )
                self.navigationActivityID = activity.id
                Logger.navigation.info("Live Activity startet: \(activity.id, privacy: .public)")
            } catch {
                Logger.navigation.error("Live Activity start: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    private func updateLiveActivity(force: Bool = false) {
        guard let id = navigationActivityID else { return }
        let now = Date()
        if !force, let last = lastActivityUpdate,
           now.timeIntervalSince(last) < Self.activityUpdateInterval { return }
        lastActivityUpdate = now
        let content = ActivityKit.ActivityContent(
            state: currentActivityState(),
            staleDate: Date().addingTimeInterval(Self.activityStaleInterval)
        )
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
