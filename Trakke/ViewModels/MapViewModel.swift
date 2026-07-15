import SwiftUI
import CoreLocation
import OSLog

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

    var isNavigating = false
    var isHeadingUp = false
    var userHeading: Double?

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
    private var lastHeadingTime: Date?
    private var lastHeadingValue: Double = 0
    private var smoothedHeading: Double = 0
    @ObservationIgnored nonisolated(unsafe) private var defaultsObserver: NSObjectProtocol?
    private static let headingMinInterval: TimeInterval = 0.2  // ~5 Hz max
    private static let headingMinDelta: Double = 2.0           // degrees
    private static let headingSmoothingFactor: Double = 0.25   // low-pass filter (0 = ignore new, 1 = no smoothing)

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
        locationManager.startUpdatingLocation()
    }

    func confirmLocationPermission() {
        showLocationPrimer = false
        requestLocationPermission()
    }

    func dismissLocationPrimer() {
        showLocationPrimer = false
    }

    func centerOn(coordinate: CLLocationCoordinate2D, zoom: Double? = nil) {
        isTrackingUser = false
        currentCenter = coordinate
        if let zoom {
            currentZoom = zoom
        }
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

        // Allow location updates to continue when the screen locks so the
        // Live Activity on the lock screen stays current. The blue status-bar
        // indicator (showsBackgroundLocationIndicator) makes this visible to
        // the user. No CLBackgroundActivitySession needed – this is a
        // continuation of the foreground session, not a persistent background
        // process, so it stops naturally if the app is force-quit.
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.distanceFilter = 1.0
        locationManager.activityType = .fitness

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopNavigation() {
        isNavigating = false
        userHeading = nil
        removeLocationObserver("navigation")
        lastHeadingTime = nil
        lastHeadingValue = 0

        // Fully stop all location services first to ensure a clean break.
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
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

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor [weak self] in
            guard let self else { return }
            let now = Date()
            if let lastTime = lastHeadingTime,
               now.timeIntervalSince(lastTime) < Self.headingMinInterval {
                var delta = abs(heading - lastHeadingValue)
                if delta > 180 { delta = 360 - delta }
                guard delta >= Self.headingMinDelta else { return }
            }
            lastHeadingTime = now
            lastHeadingValue = heading

            // Low-pass filter to smooth magnetometer jitter.
            // Handle 0/360 wrap-around by computing shortest angular delta.
            var delta = heading - smoothedHeading
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            smoothedHeading = (smoothedHeading + delta * Self.headingSmoothingFactor)
                .truncatingRemainder(dividingBy: 360)
            if smoothedHeading < 0 { smoothedHeading += 360 }

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
