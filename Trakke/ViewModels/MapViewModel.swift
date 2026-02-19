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

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationAuthStatus = locationManager.authorizationStatus
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
            } else {
                requestLocationPermission()
            }
            return
        }
        isTrackingUser = true
        locationManager.startUpdatingLocation()
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

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            userLocation = location
            if isTrackingUser {
                currentCenter = location.coordinate
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            locationAuthStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if isTrackingUser {
                    locationManager.startUpdatingLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("Location error: \(error.localizedDescription)")
        #endif
    }
}
