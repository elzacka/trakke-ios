import SwiftUI
import CoreLocation
import os
import OSLog

/// Et rektangulært kartutsnitt. Brukes som kamerakommando for å vise et helt
/// nedlastet kartområde.
struct MapBounds: Equatable, Sendable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double
}

@MainActor
@Observable
final class MapViewModel: NSObject, CLLocationManagerDelegate {
    var baseLayer: BaseLayer = .topo
    var enabledOverlays: Set<OverlayLayer> = []
    var userLocation: CLLocation?
    var isTrackingUser = false
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    var currentZoom: Double = MapConstants.defaultZoom
    var currentHeading: Double = 0
    var shouldResetHeading = false
    /// Eksplisitt zoom-mål satt av zoom-knappene. Leses og nulles av
    /// `TrakkeMapView.updateUIView` slik at kommandoen alltid når
    /// MapLibre, også når en annen kamera-animasjon (kompass-reset,
    /// centerOnUser, lokasjon-tracking) holder `isUserInteracting=true`.
    var pendingZoom: Double?
    /// Eksplisitt sentrerings-mål satt av søk, POI-valg og lignende. Leses og
    /// nulles av `TrakkeMapView.updateUIView`. Må være en egen kommando, ikke
    /// bare `currentCenter`: den vanlige sentreringen er portet bak
    /// `userTrackingMode == .none`, og MapLibre står i følge-modus så snart
    /// brukeren har trykket lokasjonsknappen. Uten denne når kommandoen
    /// aldri fram, og kartet blir stående på brukerposisjonen.
    var pendingCenter: CLLocationCoordinate2D?
    /// Eksplisitt «vis hele dette området»-kommando (nedlastet kartområde).
    /// Samme mekanikk som `pendingCenter`: leses og nulles av
    /// `TrakkeMapView.updateUIView`. Et senterpunkt alene ville ikke sagt noe
    /// om hvor stort området er, som er hele spørsmålet man stiller.
    var pendingBounds: MapBounds?
    /// Markør for siste valgte søkeresultat. Settes når brukeren trykker på
    /// et treff i søkefeltet, beholdes mens brukeren utforsker området (pan,
    /// zoom, åpning av POI/sted-detalj, navigasjon mot punktet). Overskrives
    /// av neste søkevalg. Nulles eksplisitt når brukeren skifter til en
    /// kart-modus som tar kartet i bruk for noe annet (tegning, måling,
    /// offline-områdeutvalg) eller setter et nytt punkt via trykk og hold.
    var searchPinCoordinate: CLLocationCoordinate2D?
    var showLocationPrimer = false
    var currentCenter = CLLocationCoordinate2D(
        latitude: MapConstants.defaultCenter.latitude,
        longitude: MapConstants.defaultCenter.longitude
    )

    // MARK: - Navigation State

    /// Sann når brukeren selv har flyttet kartet. Da skal visningen bli
    /// stående – også midt i navigasjon, og i begge kameramodusene. Uten
    /// dette hentet MapLibre-tracking kameraet tilbake til brukerposisjonen
    /// straks gesten slapp, og det var umulig å se på terrenget lenger fram.
    /// Kobles inn igjen ved et bevisst valg: lokasjonsknappen, kompass-
    /// knappen, eller start av navigasjon.
    var isCameraDetached = false

    var isNavigating = false
    var isHeadingUp = false
    var userHeading: Double?
    /// Usann når magnetometeret ikke kan stoles på: manglende sann nord
    /// (misvisningen er da ukjent) eller for stor `headingAccuracy`. Nær
    /// bilpanser, ryggsekkramme eller magnetdeksel bommer kompasset lett med
    /// titalls grader, og en retningspil som ikke sier fra er verre enn ingen.
    var headingIsReliable = false

    // Keyed observers so navigation and recording can co-exist without one
    // overwriting the other (a single closure slot meant starting navigation
    // mid-recording lost the recording's location updates until navigation
    // stopped).
    private var locationObservers: [String: (CLLocation) -> Void] = [:]

    func setLocationObserver(_ key: String, _ observer: @escaping (CLLocation) -> Void) {
        locationObservers[key] = observer
    }

    func removeLocationObserver(_ key: String) {
        locationObservers.removeValue(forKey: key)
    }

    private let locationManager = CLLocationManager()
    private struct HeadingThrottleState {
        var lastTime: Date?
        var lastValue: Double = 0
    }
    /// Terskles i nonisolated delegatkontekst FØR hopp til MainActor –
    /// magnetometeret fyrer hyppig under navigasjon, og forkastede
    /// oppdateringer skal ikke belaste hovedaktoren med Task-allokeringer.
    private let headingThrottle = OSAllocatedUnfairLock(initialState: HeadingThrottleState())
    /// Leses fra `locationManagerShouldDisplayHeadingCalibration`, som er
    /// nonisolated og må svare synkront – derfor et låst flagg framfor
    /// MainActor-state.
    private let calibrationAllowed = OSAllocatedUnfairLock(initialState: false)
    private var smoothedHeading: Double = 0
    /// Usann til første måling. Uten seeding starter lavpassfilteret på
    /// forrige økts verdi (eller rett nord) og bruker et par sekunder på å
    /// svinge seg inn på riktig retning.
    private var hasSmoothedHeading = false
    @ObservationIgnored nonisolated(unsafe) private var defaultsObserver: NSObjectProtocol?
    private nonisolated static let headingMinInterval: TimeInterval = 0.2  // ~5 Hz max
    private nonisolated static let headingMinDelta: Double = 2.0           // degrees
    private static let headingSmoothingFactor: Double = 0.25   // low-pass filter (0 = ignore new, 1 = no smoothing)
    /// Over denne feilmarginen i grader er pila ikke til å stole på.
    private nonisolated static let maxHeadingError: Double = 25

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationAuthStatus = locationManager.authorizationStatus

        loadOverlaysFromDefaults()
        // PreferencesSheet writes overlay flags via @AppStorage – observe
        // UserDefaults so the map state stays in sync without ContentView
        // having to mediate between the two.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.loadOverlaysFromDefaults()
            }
        }

        // Defensive cleanup: prior builds created a CLBackgroundActivitySession
        // for "navigate with screen off" support. The session persisted across
        // force-quit, leaving a Dynamic Island indicator and consuming battery
        // – incompatible with the "Mens appen er i bruk"-permission users grant.
        // Creating a fresh session invalidates any prior one, then we invalidate
        // immediately. Runs once for users upgrading from such a build.
        if UserDefaults.standard.bool(forKey: AppStorageKeys.navigationSessionActive) {
            UserDefaults.standard.set(false, forKey: AppStorageKeys.navigationSessionActive)
            CLBackgroundActivitySession().invalidate()
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.showsBackgroundLocationIndicator = false
        }
    }

    deinit {
        if let observer = defaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Overlay sync

    private func loadOverlaysFromDefaults() {
        let defaults = UserDefaults.standard
        var overlays: Set<OverlayLayer> = []
        if defaults.bool(forKey: AppStorageKeys.overlayTurrutebasen) { overlays.insert(.turrutebasen) }
if defaults.bool(forKey: AppStorageKeys.overlayNaturvernomrader) { overlays.insert(.naturvernomrader) }
        if defaults.bool(forKey: AppStorageKeys.overlayBratthetskart) { overlays.insert(.bratthetskart) }
        if defaults.bool(forKey: AppStorageKeys.overlayUtmRunenett) { overlays.insert(.utmRunenett) }
        if defaults.bool(forKey: AppStorageKeys.overlayNaturskog) { overlays.insert(.naturskog) }
        if overlays != enabledOverlays {
            enabledOverlays = overlays
        }
    }

    // MARK: - Layer Switching

    func switchLayer(to layer: BaseLayer) {
        baseLayer = layer
    }

    // MARK: - Location

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTrackingLocation() {
        guard locationAuthStatus == .authorizedWhenInUse || locationAuthStatus == .authorizedAlways else {
            if locationAuthStatus == .notDetermined {
                showLocationPrimer = true
            } else if locationAuthStatus == .denied || locationAuthStatus == .restricted {
                openAppSettings()
            }
            return
        }
        isTrackingUser = true
        isCameraDetached = false
        locationManager.startUpdatingLocation()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func stopTrackingLocation() {
        isTrackingUser = false
        locationManager.stopUpdatingLocation()
    }

    func centerOnUser() {
        guard let location = userLocation else {
            startTrackingLocation()
            return
        }
        currentCenter = location.coordinate
        isTrackingUser = true
        isCameraDetached = false
        locationManager.startUpdatingLocation()
    }

    func confirmLocationPermission() {
        showLocationPrimer = false
        requestLocationPermission()
    }

    func dismissLocationPrimer() {
        showLocationPrimer = false
    }

    /// Sentrerer kartet på et valgt punkt. Slipper både appens egen
    /// bruker-følging og MapLibres kameramodus – ber du om å se et annet sted,
    /// skal kartet ikke hoppe tilbake til deg.
    func centerOn(coordinate: CLLocationCoordinate2D, zoom: Double? = nil) {
        isTrackingUser = false
        isHeadingUp = false
        // Samme regel som for en gest: ba du om å se et annet sted, skal
        // kartet bli der til du selv henter kameraet tilbake.
        isCameraDetached = true
        currentCenter = coordinate
        pendingCenter = coordinate
        if let zoom {
            currentZoom = zoom
        }
    }

    /// Viser et helt nedlastet kartområde. Kobler fra kameraet av samme grunn
    /// som `centerOn`: ba du om å se et bestemt område, skal kartet bli der.
    func showBounds(_ bounds: MapBounds) {
        isTrackingUser = false
        isHeadingUp = false
        isCameraDetached = true
        pendingBounds = bounds
    }

    func zoomIn() {
        let next = min((currentZoom + 1).rounded(), MapConstants.maxZoom)
        currentZoom = next
        pendingZoom = next
    }

    func zoomOut() {
        let next = max((currentZoom - 1).rounded(), MapConstants.minZoom)
        currentZoom = next
        pendingZoom = next
    }

    // MARK: - Navigation

    func startNavigation() {
        guard locationAuthStatus == .authorizedWhenInUse || locationAuthStatus == .authorizedAlways else {
            startTrackingLocation()
            return
        }

        isNavigating = true
        isTrackingUser = true
        isCameraDetached = false

        // Allow location updates to continue when the screen locks so the
        // Live Activity on the lock screen stays current. The blue status-bar
        // indicator (showsBackgroundLocationIndicator) makes this visible to
        // the user. No CLBackgroundActivitySession needed – this is a
        // continuation of the foreground session, not a persistent background
        // process, so it stops naturally if the app is force-quit.
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        // Ingen distanceFilter under navigasjon: et filter stopper alle
        // callbacks når brukeren står stille, noe som fryser HUD/Live Activity
        // og utløser GPS-vaktbikkja falskt. Automatisk pause må også av –
        // iOS gjenopptar ikke oppdateringer pålitelig etter pause med låst skjerm.
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .fitness

        // Uten dette svarer iOS aldri på et ukalibrert magnetometer: standard
        // er å ikke vise kalibreringsskjermen, så en pil som bommer 30 grader
        // blir stående uten at brukeren får sjansen til å rette den.
        calibrationAllowed.withLock { $0 = true }

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopNavigation() {
        isNavigating = false
        isCameraDetached = false
        userHeading = nil
        headingIsReliable = false
        hasSmoothedHeading = false
        calibrationAllowed.withLock { $0 = false }
        removeLocationObserver("navigation")
        headingThrottle.withLock { $0 = HeadingThrottleState() }

        // Fully stop all location services first to ensure a clean break.
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .other

        // Restart basic location tracking for the map's user position dot.
        // This uses default settings (no distance filter).
        if isTrackingUser {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            userLocation = location
            if isTrackingUser {
                currentCenter = location.coordinate
            }
            for observer in locationObservers.values {
                observer(location)
            }
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        calibrationAllowed.withLock { $0 }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Målpeilingen er alltid mot sann nord. Faller retningen tilbake til
        // magnetisk nord er misvisningen med i tallet (~3 grader på Sørlandet,
        // opptil ~11 i Finnmark), og pila skal merkes som upålitelig.
        let hasTrueNorth = newHeading.trueHeading >= 0
        let heading = hasTrueNorth ? newHeading.trueHeading : newHeading.magneticHeading
        let isReliable = hasTrueNorth
            && newHeading.headingAccuracy >= 0
            && newHeading.headingAccuracy <= Self.maxHeadingError
        let now = Date()
        let passesThrottle = headingThrottle.withLock { state -> Bool in
            if let lastTime = state.lastTime,
               now.timeIntervalSince(lastTime) < Self.headingMinInterval {
                var delta = abs(heading - state.lastValue)
                if delta > 180 { delta = 360 - delta }
                guard delta >= Self.headingMinDelta else { return false }
            }
            state.lastTime = now
            state.lastValue = heading
            return true
        }
        guard passesThrottle else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            headingIsReliable = isReliable

            if hasSmoothedHeading {
                // Low-pass filter to smooth magnetometer jitter.
                // Handle 0/360 wrap-around by computing shortest angular delta.
                var delta = heading - smoothedHeading
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                smoothedHeading = (smoothedHeading + delta * Self.headingSmoothingFactor)
                    .truncatingRemainder(dividingBy: 360)
                if smoothedHeading < 0 { smoothedHeading += 360 }
            } else {
                smoothedHeading = heading
                hasSmoothedHeading = true
            }

            userHeading = smoothedHeading
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            locationAuthStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if isTrackingUser || isNavigating {
                    locationManager.startUpdatingLocation()
                }
            } else if isNavigating {
                stopNavigation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.map.error("Location error: \(error.localizedDescription, privacy: .private)")
    }
}
