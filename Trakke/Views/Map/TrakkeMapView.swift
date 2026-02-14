import SwiftUI
@preconcurrency import MapLibre

// MARK: - POI Annotation

class POIAnnotation: MLNPointAnnotation {
    let poi: POI

    init(poi: POI) {
        self.poi = poi
        super.init()
        self.coordinate = poi.coordinate
        self.title = poi.name
        self.subtitle = poi.category.displayName
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }
}

// MARK: - Map View

struct TrakkeMapView: UIViewRepresentable {
    @Bindable var viewModel: MapViewModel
    var pois: [POI] = []
    var onViewportChanged: ((ViewportBounds, Double) -> Void)?
    var onPOISelected: ((POI) -> Void)?

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = KartverketTileService.styleURL(for: viewModel.baseLayer)
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)

        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.compassViewPosition = .topRight
        mapView.logoView.isHidden = true
        mapView.attributionButtonPosition = .bottomLeft

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

        // Center map on viewModel's current center/zoom
        let vmCenter = viewModel.currentCenter
        let currentCenter = mapView.centerCoordinate
        let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
            .distance(from: CLLocation(latitude: vmCenter.latitude, longitude: vmCenter.longitude))

        if distance > 5 || abs(mapView.zoomLevel - viewModel.currentZoom) > 0.5 {
            mapView.setCenter(vmCenter, zoomLevel: viewModel.currentZoom, animated: true)
        }

        // Update POI annotations
        context.coordinator.updateAnnotations(on: mapView, pois: pois)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onViewportChanged: onViewportChanged, onPOISelected: onPOISelected)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        let viewModel: MapViewModel
        let onViewportChanged: ((ViewportBounds, Double) -> Void)?
        let onPOISelected: ((POI) -> Void)?
        private var currentPOIIds: Set<String> = []

        init(
            viewModel: MapViewModel,
            onViewportChanged: ((ViewportBounds, Double) -> Void)?,
            onPOISelected: ((POI) -> Void)?
        ) {
            self.viewModel = viewModel
            self.onViewportChanged = onViewportChanged
            self.onPOISelected = onPOISelected
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            viewModel.currentZoom = mapView.zoomLevel
            viewModel.currentCenter = mapView.centerCoordinate

            if viewModel.isTrackingUser, let userLocation = viewModel.userLocation {
                let center = mapView.centerCoordinate
                let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    .distance(from: userLocation)
                if distance > 50 {
                    viewModel.isTrackingUser = false
                }
            }

            // Report viewport change
            let bounds = mapView.visibleCoordinateBounds
            let viewport = ViewportBounds(
                north: bounds.ne.latitude,
                south: bounds.sw.latitude,
                east: bounds.ne.longitude,
                west: bounds.sw.longitude
            )
            onViewportChanged?(viewport, mapView.zoomLevel)
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coordinate = userLocation?.coordinate,
                  CLLocationCoordinate2DIsValid(coordinate) else { return }
            viewModel.userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let poiAnnotation = annotation as? POIAnnotation else { return nil }

            let reuseId = "poi-\(poiAnnotation.poi.category.rawValue)"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)

                let circle = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                circle.backgroundColor = UIColor(hex: poiAnnotation.poi.category.color)
                circle.layer.cornerRadius = 15
                circle.layer.borderWidth = 2
                circle.layer.borderColor = UIColor.white.cgColor
                circle.layer.shadowColor = UIColor.black.cgColor
                circle.layer.shadowOpacity = 0.3
                circle.layer.shadowOffset = CGSize(width: 0, height: 1)
                circle.layer.shadowRadius = 2
                view?.addSubview(circle)
            }

            return view
        }

        func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            if let poiAnnotation = annotation as? POIAnnotation {
                onPOISelected?(poiAnnotation.poi)
            }
        }

        func updateAnnotations(on mapView: MLNMapView, pois: [POI]) {
            let newIds = Set(pois.map(\.id))
            guard newIds != currentPOIIds else { return }

            // Remove old POI annotations
            let existing = mapView.annotations?.compactMap { $0 as? POIAnnotation } ?? []
            if !existing.isEmpty {
                mapView.removeAnnotations(existing)
            }

            // Add new POI annotations
            let annotations = pois.map { POIAnnotation(poi: $0) }
            if !annotations.isEmpty {
                mapView.addAnnotations(annotations)
            }

            currentPOIIds = newIds
        }
    }
}

// MARK: - UIColor Hex Extension

private extension UIColor {
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
