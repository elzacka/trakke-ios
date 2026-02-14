import SwiftUI
import CoreLocation

@Observable
final class MapViewModel: NSObject, CLLocationManagerDelegate {
    var baseLayer: BaseLayer = .topo
    var userLocation: CLLocation?
    var isTrackingUser = false
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    var currentZoom: Double = MapConstants.defaultZoom
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
            requestLocationPermission()
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
    }

    func centerOn(coordinate: CLLocationCoordinate2D, zoom: Double? = nil) {
        isTrackingUser = false
        currentCenter = coordinate
        if let zoom {
            currentZoom = zoom
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        if isTrackingUser {
            currentCenter = location.coordinate
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthStatus = manager.authorizationStatus
        if locationAuthStatus == .authorizedWhenInUse || locationAuthStatus == .authorizedAlways {
            if isTrackingUser {
                locationManager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("Location error: \(error.localizedDescription)")
        #endif
    }
}
