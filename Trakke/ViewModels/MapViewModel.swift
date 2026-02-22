import SwiftUI
import CoreLocation

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
    var searchPinCoordinate: CLLocationCoordinate2D?
    var showLocationPrimer = false
    var currentCenter = CLLocationCoordinate2D(
        latitude: MapConstants.defaultCenter.latitude,
        longitude: MapConstants.defaultCenter.longitude
    )

    // MARK: - Navigation State

    var isNavigating = false
    var userHeading: Double?
    var onLocationUpdate: ((CLLocation) -> Void)?

    private let locationManager = CLLocationManager()
    private var backgroundSession: CLBackgroundActivitySession?
    private var lastHeadingTime: Date?
    private var lastHeadingValue: Double = 0
    private static let headingMinInterval: TimeInterval = 0.2  // ~5 Hz max
    private static let headingMinDelta: Double = 2.0           // degrees

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationAuthStatus = locationManager.authorizationStatus

        // Clean up any orphaned CLBackgroundActivitySession from a previous
        // crash or force-quit during active navigation. CLBackgroundActivitySession
        // persists across app terminations; creating a new session invalidates
        // any existing one, then we immediately invalidate the new one.
        if UserDefaults.standard.bool(forKey: "navigationSessionActive") {
            UserDefaults.standard.set(false, forKey: "navigationSessionActive")
            CLBackgroundActivitySession().invalidate()
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.showsBackgroundLocationIndicator = false
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
        currentZoom = min((currentZoom + 1).rounded(), MapConstants.maxZoom)
    }

    func zoomOut() {
        currentZoom = max((currentZoom - 1).rounded(), MapConstants.minZoom)
    }

    // MARK: - Navigation

    private var supportsBackgroundLocation: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") == true
    }

    func startNavigation() {
        guard locationAuthStatus == .authorizedWhenInUse || locationAuthStatus == .authorizedAlways else {
            startTrackingLocation()
            return
        }

        isNavigating = true
        isTrackingUser = true

        // Configure for navigation: more frequent updates
        locationManager.distanceFilter = 5.0
        locationManager.activityType = .fitness

        // CLBackgroundActivitySession keeps the app alive for location updates
        // when the user navigates away. Requires UIBackgroundModes: location in Info.plist.
        // The session is held as a strong reference and invalidated in stopNavigation().
        // We track the active state in UserDefaults so orphaned sessions from
        // crashes can be cleaned up on next launch (see init).
        if supportsBackgroundLocation {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            backgroundSession = CLBackgroundActivitySession()
            UserDefaults.standard.set(true, forKey: "navigationSessionActive")
        }

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopNavigation() {
        isNavigating = false
        userHeading = nil
        onLocationUpdate = nil
        lastHeadingTime = nil
        lastHeadingValue = 0

        // Fully stop all location services first to ensure a clean break.
        // This prevents any navigation-mode settings (background updates,
        // indicator, distance filter) from lingering.
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .other

        backgroundSession?.invalidate()
        backgroundSession = nil
        UserDefaults.standard.set(false, forKey: "navigationSessionActive")

        // Restart basic location tracking (without background mode) for the
        // map's user position dot. This uses default settings (no distance
        // filter, no background indicator).
        if isTrackingUser {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            userLocation = location
            if isTrackingUser {
                currentCenter = location.coordinate
            }
            onLocationUpdate?(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            let now = Date()
            if let lastTime = lastHeadingTime,
               now.timeIntervalSince(lastTime) < Self.headingMinInterval {
                // Allow through only if angle changed significantly
                var delta = abs(heading - lastHeadingValue)
                if delta > 180 { delta = 360 - delta }
                guard delta >= Self.headingMinDelta else { return }
            }
            lastHeadingTime = now
            lastHeadingValue = heading
            userHeading = heading
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
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
        #if DEBUG
        print("Location error: \(error.localizedDescription)")
        #endif
    }
}
