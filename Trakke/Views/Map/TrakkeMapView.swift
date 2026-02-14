import SwiftUI
import MapLibre

struct TrakkeMapView: UIViewRepresentable {
    @Bindable var viewModel: MapViewModel
    var onZoomChanged: ((Double) -> Void)?

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = KartverketTileService.styleURL(for: viewModel.baseLayer)
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)

        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.compassViewPosition = .topRight
        mapView.logoView.isHidden = true
        mapView.attributionButtonPosition = .bottomLeft

        // Map behavior
        mapView.setCenter(
            CLLocationCoordinate2D(
                latitude: MapConstants.defaultCenter.latitude,
                longitude: MapConstants.defaultCenter.longitude
            ),
            zoomLevel: MapConstants.defaultZoom,
            animated: false
        )
        mapView.minimumZoomLevel = MapConstants.minZoom
        mapView.maximumZoomLevel = MapConstants.maxZoom
        mapView.maximumPitch = MapConstants.maxPitch

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Update base layer if changed
        let expectedSourceID = viewModel.baseLayer.sourceID
        let currentHasSource = mapView.style?.source(withIdentifier: expectedSourceID) != nil

        if !currentHasSource {
            let newStyleURL = KartverketTileService.styleURL(for: viewModel.baseLayer)
            mapView.styleURL = newStyleURL
        }

        // Center on user if tracking
        if viewModel.isTrackingUser, let location = viewModel.userLocation {
            let currentCenter = mapView.centerCoordinate
            let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
                .distance(from: location)
            if distance > 5 {
                mapView.setCenter(location.coordinate, animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onZoomChanged: onZoomChanged)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        let viewModel: MapViewModel
        let onZoomChanged: ((Double) -> Void)?

        init(viewModel: MapViewModel, onZoomChanged: ((Double) -> Void)?) {
            self.viewModel = viewModel
            self.onZoomChanged = onZoomChanged
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            viewModel.currentZoom = mapView.zoomLevel
            viewModel.currentCenter = mapView.centerCoordinate
            onZoomChanged?(mapView.zoomLevel)

            if viewModel.isTrackingUser, let userLocation = viewModel.userLocation {
                let center = mapView.centerCoordinate
                let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    .distance(from: userLocation)
                if distance > 50 {
                    viewModel.isTrackingUser = false
                }
            }
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coordinate = userLocation?.coordinate,
                  CLLocationCoordinate2DIsValid(coordinate) else { return }
            viewModel.userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}
