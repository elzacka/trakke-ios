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
    /// Horisontal usikkerhet i den sist brukte posisjonen. Styrer
    /// ankomstradiusen og lar HUD-en si fra når avstandstallet er grovt.
    var gpsAccuracy: CLLocationAccuracy = 0
    /// Usann når avstanden er innenfor GPS-usikkerheten. Da er peilingen ren
    /// støy, og pila fryses i stedet for å snurre rundt.
    var isBearingReliable = true
    /// Estimert gangtid til målet, målt på hvor raskt brukeren faktisk
    /// nærmer seg. `nil` før første posisjon og etter ankomst.
    var estimatedTravelTime: TimeInterval?

    // MARK: - Private State

    /// Største observerte avstand til destinasjonen i økten – hindrer
    /// feilaktig "Fremme!" når brukeren starter nær destinasjonen (f.eks.
    /// retrace av rundtur). Ankomst krever at brukeren enten har vært lengre
    /// unna enn 2x terskelen, eller har nærmet seg minst én terskel – slik
    /// fungerer ankomst også for mål brukeren starter 30-60 m fra.
    private var maxObservedDistance: Double = 0
    /// Antall påfølgende posisjoner innenfor ankomstradiusen. GPS-støy gir
    /// enkeltfikser som ligger titalls meter feil; ankomst skal ikke kunne
    /// utløses av én slik.
    private var arrivalHits = 0
    /// Usann til første pålitelige peiling er beregnet. Starter brukeren
    /// oppå målet, må pila vise *noe* framfor å stå fast på 0 grader (nord).
    private var hasComputedBearing = false
    private var lastProcessedTime: Date?
    private var navigationActivityID: String?
    private var lastActivityUpdate: Date?

    /// Startpunktet for gjeldende tempomåling: avstand til målet og
    /// tidspunktet den ble målt.
    private var travelTimeSample: (distance: Double, time: Date)?
    /// Glattet tempo mot målet (m/s). Måles på faktisk redusert avstand, ikke
    /// på GPS-fart: går du en omvei rundt et vann, nærmer du deg saktere enn
    /// du går, og estimatet skal vise det.
    private var closingRate: Double?

    private static let activityUpdateInterval: TimeInterval = 5.0
    /// Romslig stale-frist: mister enheten GPS-fiks en stund (skog, juv,
    /// innendørs) skal låseskjerm/Dynamic Island vise siste kjente verdi i
    /// stedet for å nedtones etter ett minutt.
    private static let activityStaleInterval: TimeInterval = 600

    /// Watchdog som slår GPS-kvaliteten til `.lost` hvis ingen posisjon
    /// kommer inn innen `gpsWatchdogTimeout`. `GPSQuality(accuracy:)` dekker
    /// bare unøyaktighet, ikke fravær av signal.
    private var gpsWatchdogTask: Task<Void, Never>?

    // MARK: - Terskler

    /// Ankomstradius i beste fall. En fast 30-metersradius meldte «Fremme» et
    /// halvt kvartal for tidlig på korte turer i bebyggelse; radiusen skal
    /// følge hvor presis fiksen faktisk er.
    private nonisolated static let minArrivalThreshold: Double = 12
    /// Øvre grense, for fikser som er så grove at en liten radius aldri ville
    /// slå til.
    private nonisolated static let maxArrivalThreshold: Double = 30
    /// Ankomstradiusen som andel av usikkerheten. 1,5x gir «Fremme» innenfor
    /// ett standardavvik uten å kreve at støyen forsvinner helt.
    private nonisolated static let arrivalAccuracyFactor: Double = 1.5
    /// Antall påfølgende posisjoner innenfor radiusen før ankomst meldes.
    private static let arrivalConfirmations = 2
    /// Hysterese: hvor mye lenger unna enn radiusen brukeren må komme før
    /// «Fremme» fjernes igjen. Uten dette blir banneret stående resten av
    /// økten selv om brukeren går videre.
    private static let arrivalExitMargin: Double = 15

    /// Fikser grovere enn dette brukes ikke til avstand, peiling eller
    /// ankomst. De vises fortsatt som redusert/tapt GPS.
    private static let maxUsableAccuracy: CLLocationAccuracy = 50
    /// Første callback etter `startUpdatingLocation` er ofte en hurtigbufret
    /// posisjon fra minutter tilbake. Den skal ikke sette tempo eller ankomst.
    private static let maxFixAge: TimeInterval = 15
    /// Under denne avstanden domineres peilingen av GPS-støy.
    private static let minBearingDistance: Double = 10

    /// Måleintervall for tempo. Kortere vinduer drukner i GPS-støy: ±5 m
    /// støy på ett sekund er ±5 m/s.
    private static let travelTimeSampleInterval: TimeInterval = 10
    private static let closingRateSmoothing: Double = 0.4
    /// Under dette tempoet regnes brukeren som stående – da beholdes forrige
    /// måling i stedet for at estimatet blåses opp av en pause.
    private static let minUsableSpeed: Double = 0.15   // 0,5 km/t
    private static let maxWalkingSpeed: Double = 2.5   // 9 km/t
    private static let fallbackWalkingSpeed: Double = 1.1  // 4 km/t

    /// Porten mot for hyppige oppdateringer. Må ligge godt under
    /// CoreLocations ~1 Hz, ellers faller annenhver posisjon utenfor og
    /// HUD-en blir opptil to sekunder gammel. Instansvariabler (ikke static)
    /// slik at tester kan korte dem ned uten å påvirke parallelle tester.
    var minUpdateInterval: TimeInterval = 0.5
    var gpsWatchdogTimeout: TimeInterval = 15

    // MARK: - Start Compass Navigation

    func startCompassNavigation(to dest: CLLocationCoordinate2D) {
        destination = dest
        isActive = true
        isPaused = false
        hasArrived = false
        maxObservedDistance = 0
        arrivalHits = 0
        hasComputedBearing = false
        gpsAccuracy = 0
        isBearingReliable = true
        estimatedTravelTime = nil
        travelTimeSample = nil
        closingRate = nil
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
        // Tempomålingen står stille under pause; start et nytt vindu i stedet
        // for å tolke pausen som svært langsom gange.
        travelTimeSample = nil
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
        gpsAccuracy = 0
        isBearingReliable = true
        estimatedTravelTime = nil
        travelTimeSample = nil
        closingRate = nil
        maxObservedDistance = 0
        arrivalHits = 0
        hasComputedBearing = false
        lastProcessedTime = nil
        lastActivityUpdate = nil
    }

    // MARK: - Process Location Update

    func processLocationUpdate(_ location: CLLocation) async {
        guard isActive, !isPaused else { return }

        let now = Date()
        if let last = lastProcessedTime,
           now.timeIntervalSince(last) < minUpdateInterval {
            return
        }

        // Kvaliteten meldes fra alle fikser – også de vi ikke regner på.
        // Brukeren skal se at signalet er dårlig, ikke bare at tallet står
        // stille.
        gpsQuality = GPSQuality(accuracy: location.horizontalAccuracy)

        guard Self.isUsable(location, now: now) else { return }

        lastProcessedTime = now
        gpsAccuracy = location.horizontalAccuracy
        restartGPSWatchdog()
        processCompassUpdate(location, now: now)
    }

    /// En posisjon brukes bare til geometri hvis den er gyldig, fersk og
    /// presis nok. Uten dette filteret kan én utligger både utløse «Fremme»
    /// for tidlig og blåse opp `maxObservedDistance`.
    private static func isUsable(_ location: CLLocation, now: Date) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxUsableAccuracy,
              location.coordinate.latitude.isFinite,
              location.coordinate.longitude.isFinite else { return false }
        return now.timeIntervalSince(location.timestamp) <= maxFixAge
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

    private func processCompassUpdate(_ location: CLLocation, now: Date) {
        guard let dest = destination else { return }

        compassDistance = MeasurementService.distance(from: location.coordinate, to: dest)

        // Nærmere målet enn usikkerheten er retningen ren støy. Da beholdes
        // siste pålitelige peiling, slik at pila ikke snurrer mens brukeren
        // ser seg om etter målet.
        let bearingFloor = max(Self.minBearingDistance, location.horizontalAccuracy)
        isBearingReliable = compassDistance > bearingFloor
        if isBearingReliable || !hasComputedBearing {
            compassBearing = Bearing.bearing(from: location.coordinate, to: dest)
            hasComputedBearing = true
        }

        maxObservedDistance = max(maxObservedDistance, compassDistance)
        updateArrival(accuracy: location.horizontalAccuracy)
        updateTravelTime(location, now: now)

        updateLiveActivity()
    }

    /// Ankomstradius etter hvor presis fiksen er. God fiks i åpent lende gir
    /// 12 m – «Fremme» skal bety at du står ved målet.
    nonisolated static func arrivalThreshold(for accuracy: CLLocationAccuracy) -> Double {
        guard accuracy > 0 else { return minArrivalThreshold }
        return min(
            maxArrivalThreshold,
            max(minArrivalThreshold, accuracy * arrivalAccuracyFactor)
        )
    }

    private func updateArrival(accuracy: CLLocationAccuracy) {
        let threshold = Self.arrivalThreshold(for: accuracy)

        if hasArrived {
            if compassDistance > threshold + Self.arrivalExitMargin {
                hasArrived = false
                arrivalHits = 0
                updateLiveActivity(force: true)
            }
            return
        }

        let hasMovedMeaningfully = maxObservedDistance > threshold * 2
            || maxObservedDistance - compassDistance > threshold

        guard compassDistance < threshold, hasMovedMeaningfully else {
            arrivalHits = 0
            return
        }

        arrivalHits += 1
        guard arrivalHits >= Self.arrivalConfirmations else { return }

        hasArrived = true
        estimatedTravelTime = nil
        HapticFeedback.success()
        updateLiveActivity(force: true)
    }

    // MARK: - Gangtid

    private func updateTravelTime(_ location: CLLocation, now: Date) {
        if let sample = travelTimeSample {
            let elapsed = now.timeIntervalSince(sample.time)
            if elapsed >= Self.travelTimeSampleInterval {
                let rate = min(
                    Self.maxWalkingSpeed,
                    (sample.distance - compassDistance) / elapsed
                )
                // Står brukeren stille, eller går et strekk bort fra målet,
                // beholdes forrige tempo. Et rødt lys skal ikke doble
                // estimatet.
                if rate >= Self.minUsableSpeed {
                    closingRate = closingRate.map {
                        $0 + (rate - $0) * Self.closingRateSmoothing
                    } ?? rate
                }
                travelTimeSample = (compassDistance, now)
            }
        } else {
            travelTimeSample = (compassDistance, now)
        }

        guard !hasArrived else {
            estimatedTravelTime = nil
            return
        }

        // Før første måling: GPS-farten hvis den finnes, ellers 4 km/t.
        // `location.speed` er negativ når enheten ikke kan måle fart.
        let speed = closingRate
            ?? max(Self.fallbackWalkingSpeed, min(Self.maxWalkingSpeed, location.speed))
        estimatedTravelTime = compassDistance / speed
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
            bearing: Int(compassBearing.rounded()) % 360,
            cardinalDirection: cardinalDirection(for: compassBearing),
            distance: MeasurementService.formatDistance(compassDistance),
            isPaused: isPaused,
            hasArrived: hasArrived,
            travelTime: estimatedTravelTime.map(MeasurementService.formatDuration)
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
