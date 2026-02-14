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

// MARK: - Route Drawing Point

class RoutePointAnnotation: MLNPointAnnotation {
    let index: Int

    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.index = index
        super.init()
        self.coordinate = coordinate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }
}

// MARK: - Map View

struct TrakkeMapView: UIViewRepresentable {
    @Bindable var viewModel: MapViewModel
    var pois: [POI] = []
    var routes: [Route] = []
    var drawingCoordinates: [CLLocationCoordinate2D] = []
    var isDrawing = false
    var onViewportChanged: ((ViewportBounds, Double) -> Void)?
    var onPOISelected: ((POI) -> Void)?
    var onMapTapped: ((CLLocationCoordinate2D) -> Void)?

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

        // Tap gesture for route drawing
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)

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

        // Update route polylines
        context.coordinator.updateRoutePolylines(on: mapView, routes: routes)

        // Update drawing overlay
        context.coordinator.updateDrawingOverlay(
            on: mapView,
            coordinates: drawingCoordinates,
            isDrawing: isDrawing
        )

        context.coordinator.isDrawingMode = isDrawing
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            viewModel: viewModel,
            onViewportChanged: onViewportChanged,
            onPOISelected: onPOISelected,
            onMapTapped: onMapTapped
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate, @preconcurrency UIGestureRecognizerDelegate {
        let viewModel: MapViewModel
        let onViewportChanged: ((ViewportBounds, Double) -> Void)?
        let onPOISelected: ((POI) -> Void)?
        let onMapTapped: ((CLLocationCoordinate2D) -> Void)?
        var isDrawingMode = false

        private var currentPOIIds: Set<String> = []
        private var currentRouteIds: Set<String> = []
        private var drawingPolyline: MLNPolyline?
        private var drawingAnnotations: [RoutePointAnnotation] = []

        init(
            viewModel: MapViewModel,
            onViewportChanged: ((ViewportBounds, Double) -> Void)?,
            onPOISelected: ((POI) -> Void)?,
            onMapTapped: ((CLLocationCoordinate2D) -> Void)?
        ) {
            self.viewModel = viewModel
            self.onViewportChanged = onViewportChanged
            self.onPOISelected = onPOISelected
            self.onMapTapped = onMapTapped
        }

        // MARK: - Tap Gesture

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard isDrawingMode, let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onMapTapped?(coordinate)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // MARK: - Map Delegate

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
            if let poiAnnotation = annotation as? POIAnnotation {
                return poiAnnotationView(for: poiAnnotation, on: mapView)
            }
            if let routePoint = annotation as? RoutePointAnnotation {
                return routePointView(for: routePoint, on: mapView)
            }
            return nil
        }

        func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            if let poiAnnotation = annotation as? POIAnnotation {
                onPOISelected?(poiAnnotation.poi)
            }
        }

        func mapView(
            _ mapView: MLNMapView,
            strokeColorForShapeAnnotation annotation: MLNShape
        ) -> UIColor {
            if annotation === drawingPolyline {
                return UIColor(hex: "#3e4533")
            }
            if let polyline = annotation as? MLNPolyline, let colorHex = polyline.title {
                return UIColor(hex: colorHex)
            }
            return UIColor(hex: "#3e4533")
        }

        func mapView(
            _ mapView: MLNMapView,
            lineWidthForPolylineAnnotation annotation: MLNPolyline
        ) -> CGFloat {
            annotation === drawingPolyline ? 3 : 4
        }

        func mapView(
            _ mapView: MLNMapView,
            alphaForShapeAnnotation annotation: MLNShape
        ) -> CGFloat {
            annotation === drawingPolyline ? 0.8 : 0.9
        }

        // MARK: - POI Annotations

        func updateAnnotations(on mapView: MLNMapView, pois: [POI]) {
            let newIds = Set(pois.map(\.id))
            guard newIds != currentPOIIds else { return }

            let existing = mapView.annotations?.compactMap { $0 as? POIAnnotation } ?? []
            if !existing.isEmpty {
                mapView.removeAnnotations(existing)
            }

            let annotations = pois.map { POIAnnotation(poi: $0) }
            if !annotations.isEmpty {
                mapView.addAnnotations(annotations)
            }

            currentPOIIds = newIds
        }

        // MARK: - Route Polylines

        func updateRoutePolylines(on mapView: MLNMapView, routes: [Route]) {
            let newIds = Set(routes.map(\.id))
            guard newIds != currentRouteIds else { return }

            // Remove old route polylines (exclude drawing polyline and point annotations)
            let existingPolylines = mapView.annotations?.compactMap { annotation -> MLNPolyline? in
                guard let polyline = annotation as? MLNPolyline,
                      polyline !== drawingPolyline,
                      !(annotation is POIAnnotation),
                      !(annotation is RoutePointAnnotation) else { return nil }
                return polyline
            } ?? []
            if !existingPolylines.isEmpty {
                mapView.removeAnnotations(existingPolylines)
            }

            for route in routes {
                let coords = route.coordinates.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                guard coords.count >= 2 else { continue }

                var mutableCoords = coords
                let polyline = MLNPolyline(coordinates: &mutableCoords, count: UInt(coords.count))
                polyline.title = route.color ?? "#3e4533"
                mapView.addAnnotation(polyline)
            }

            currentRouteIds = newIds
        }

        // MARK: - Drawing Overlay

        func updateDrawingOverlay(
            on mapView: MLNMapView,
            coordinates: [CLLocationCoordinate2D],
            isDrawing: Bool
        ) {
            // Remove old drawing elements
            if let existing = drawingPolyline {
                mapView.removeAnnotation(existing)
                drawingPolyline = nil
            }
            if !drawingAnnotations.isEmpty {
                mapView.removeAnnotations(drawingAnnotations)
                drawingAnnotations = []
            }

            guard isDrawing, !coordinates.isEmpty else { return }

            // Add point markers
            let pointAnnotations = coordinates.enumerated().map { index, coord in
                RoutePointAnnotation(coordinate: coord, index: index)
            }
            mapView.addAnnotations(pointAnnotations)
            drawingAnnotations = pointAnnotations

            // Add polyline if 2+ points
            if coordinates.count >= 2 {
                var mutableCoords = coordinates
                let polyline = MLNPolyline(
                    coordinates: &mutableCoords,
                    count: UInt(coordinates.count)
                )
                mapView.addAnnotation(polyline)
                drawingPolyline = polyline
            }
        }

        // MARK: - Annotation Views

        private func poiAnnotationView(
            for annotation: POIAnnotation,
            on mapView: MLNMapView
        ) -> MLNAnnotationView? {
            let reuseId = "poi-\(annotation.poi.category.rawValue)"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)

                let circle = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                circle.backgroundColor = UIColor(hex: annotation.poi.category.color)
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

        private func routePointView(
            for annotation: RoutePointAnnotation,
            on mapView: MLNMapView
        ) -> MLNAnnotationView? {
            let reuseId = "route-point"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: 20, height: 20)

                let dot = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
                dot.backgroundColor = UIColor(hex: "#3e4533")
                dot.layer.cornerRadius = 10
                dot.layer.borderWidth = 2
                dot.layer.borderColor = UIColor.white.cgColor
                view?.addSubview(dot)
            }

            return view
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
