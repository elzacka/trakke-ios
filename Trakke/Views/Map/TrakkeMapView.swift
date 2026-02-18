import SwiftUI
@preconcurrency import MapLibre

// MARK: - MapView Subclass

/// Overrides `automaticallyAdjustsContentInset` to return false from the start.
/// MLNMapView's init reads the deprecated UIViewController.automaticallyAdjustsScrollViewInsets
/// when this property is true (the default). By overriding via Objective-C dynamic dispatch,
/// the check is skipped even during super.init, preventing the console warning.
private class TrakkeMLNMapView: MLNMapView {
    override var automaticallyAdjustsContentInset: Bool {
        get { false }
        set { }
    }
}

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

// MARK: - Measurement Point

class MeasurementPointAnnotation: MLNPointAnnotation {
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

// MARK: - Selection Corner Annotation

class SelectionCornerAnnotation: MLNPointAnnotation {
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

// MARK: - Waypoint Annotation

class WaypointAnnotation: MLNPointAnnotation {
    let waypoint: Waypoint

    init(waypoint: Waypoint) {
        self.waypoint = waypoint
        super.init()
        guard waypoint.coordinates.count >= 2 else { return }
        self.coordinate = CLLocationCoordinate2D(
            latitude: waypoint.coordinates[1],
            longitude: waypoint.coordinates[0]
        )
        self.title = waypoint.name
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }
}

// MARK: - Search Pin Annotation

class SearchPinAnnotation: MLNPointAnnotation {}

// MARK: - Map View

struct TrakkeMapView: UIViewRepresentable {
    @Bindable var viewModel: MapViewModel
    var pois: [POI] = []
    var routes: [Route] = []
    var waypoints: [Waypoint] = []
    var drawingCoordinates: [CLLocationCoordinate2D] = []
    var isDrawing = false
    var selectionCorner1: CLLocationCoordinate2D?
    var selectionCorner2: CLLocationCoordinate2D?
    var measurementCoordinates: [CLLocationCoordinate2D] = []
    var measurementMode: MeasurementMode?
    var searchPinCoordinate: CLLocationCoordinate2D?
    var enabledOverlays: Set<OverlayLayer> = []
    var showWeatherWidget = false
    var enableRotation = true
    var onViewportChanged: ((ViewportBounds, Double) -> Void)?
    var onPOISelected: ((POI) -> Void)?
    var onWaypointSelected: ((Waypoint) -> Void)?
    var onMapTapped: ((CLLocationCoordinate2D) -> Void)?
    var onMapLongPressed: ((CLLocationCoordinate2D) -> Void)?
    var onRoutePointDragged: ((Int, CLLocationCoordinate2D) -> Void)?
    var onMeasurementPointDragged: ((Int, CLLocationCoordinate2D) -> Void)?
    var onSelectionCornerDragged: ((Int, CLLocationCoordinate2D) -> Void)?

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = KartverketTileService.styleURL(for: viewModel.baseLayer)
        let mapView = TrakkeMLNMapView(frame: .zero, styleURL: styleURL)

        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.compassView.compassVisibility = .hidden
        mapView.allowsRotating = enableRotation
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true

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

        // Long-press gesture for waypoint placement
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressGesture)

        // Custom pan gesture for dragging selection corners.
        // This replaces MapLibre's built-in isDraggable system which does not
        // update annotation.coordinate in real-time during drag.
        let cornerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleCornerPan(_:))
        )
        cornerPan.delegate = context.coordinator
        context.coordinator.cornerPanGesture = cornerPan
        mapView.addGestureRecognizer(cornerPan)

        // Make the map's built-in pan gesture wait for our corner pan to fail first.
        // This prevents the map from scrolling when the user drags a corner.
        for gesture in mapView.gestureRecognizers ?? [] {
            if gesture is UIPanGestureRecognizer && gesture !== cornerPan {
                gesture.require(toFail: cornerPan)
            }
        }

        // Store initial desired overlays for didFinishLoading to pick up
        context.coordinator.desiredOverlays = enabledOverlays

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        mapView.compassView.compassVisibility = .hidden
        mapView.allowsRotating = enableRotation

        // Reset heading if requested
        if viewModel.shouldResetHeading {
            mapView.setDirection(0, animated: true)
            viewModel.shouldResetHeading = false
        }

        // Update base layer only when actually changed
        if viewModel.baseLayer != context.coordinator.appliedBaseLayer {
            context.coordinator.appliedBaseLayer = viewModel.baseLayer
            let newStyleURL = KartverketTileService.styleURL(for: viewModel.baseLayer)
            mapView.styleURL = newStyleURL
        }

        // Update overlay layers (stores desired state; reconciles if style is loaded)
        context.coordinator.updateOverlays(on: mapView, enabled: enabledOverlays)

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

        // Update waypoint annotations
        context.coordinator.updateWaypointAnnotations(on: mapView, waypoints: waypoints)

        // Update route polylines
        context.coordinator.updateRoutePolylines(on: mapView, routes: routes)

        // Update drawing overlay
        context.coordinator.updateDrawingOverlay(
            on: mapView,
            coordinates: drawingCoordinates,
            isDrawing: isDrawing
        )

        // Update selection rectangle
        context.coordinator.updateSelectionRect(
            on: mapView,
            corner1: selectionCorner1,
            corner2: selectionCorner2
        )

        // Update measurement overlay
        context.coordinator.updateMeasurementOverlay(
            on: mapView,
            coordinates: measurementCoordinates,
            mode: measurementMode
        )

        // Update search pin
        context.coordinator.updateSearchPin(on: mapView, coordinate: searchPinCoordinate)

        context.coordinator.isDrawingMode = isDrawing
        context.coordinator.isMeasuringMode = measurementMode != nil
        context.coordinator.isSelectingArea = selectionCorner1 != nil
        context.coordinator.currentMeasurementMode = measurementMode
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            viewModel: viewModel,
            onViewportChanged: onViewportChanged,
            onPOISelected: onPOISelected,
            onWaypointSelected: onWaypointSelected,
            onMapTapped: onMapTapped,
            onMapLongPressed: onMapLongPressed,
            onRoutePointDragged: onRoutePointDragged,
            onMeasurementPointDragged: onMeasurementPointDragged,
            onSelectionCornerDragged: onSelectionCornerDragged
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate, UIGestureRecognizerDelegate {
        let viewModel: MapViewModel
        let onViewportChanged: ((ViewportBounds, Double) -> Void)?
        let onPOISelected: ((POI) -> Void)?
        let onWaypointSelected: ((Waypoint) -> Void)?
        let onMapTapped: ((CLLocationCoordinate2D) -> Void)?
        let onMapLongPressed: ((CLLocationCoordinate2D) -> Void)?
        let onRoutePointDragged: ((Int, CLLocationCoordinate2D) -> Void)?
        let onMeasurementPointDragged: ((Int, CLLocationCoordinate2D) -> Void)?
        let onSelectionCornerDragged: ((Int, CLLocationCoordinate2D) -> Void)?
        var isDrawingMode = false
        var isMeasuringMode = false
        var isSelectingArea = false
        var currentMeasurementMode: MeasurementMode?
        var appliedBaseLayer: BaseLayer = .topo
        var desiredOverlays: Set<OverlayLayer> = []
        var appliedOverlays: Set<OverlayLayer> = []

        // Custom corner drag state (replaces MapLibre's isDraggable system)
        var cornerPanGesture: UIPanGestureRecognizer?
        private var isDraggingSelection = false
        private var draggingCornerIndex: Int?

        private var currentPOIIds: Set<String> = []
        private var currentWaypointIds: Set<String> = []
        private var currentRouteIds: Set<String> = []
        private var drawingPolyline: MLNPolyline?
        private var drawingAnnotations: [RoutePointAnnotation] = []
        private var selectionPolygon: MLNPolygon?
        private var selectionPolyline: MLNPolyline?
        private var selectionAnnotations: [SelectionCornerAnnotation] = []
        private var measurementPolyline: MLNPolyline?
        private var measurementPolygon: MLNPolygon?
        private var measurementAnnotations: [MeasurementPointAnnotation] = []
        private var searchPinAnnotation: SearchPinAnnotation?

        init(
            viewModel: MapViewModel,
            onViewportChanged: ((ViewportBounds, Double) -> Void)?,
            onPOISelected: ((POI) -> Void)?,
            onWaypointSelected: ((Waypoint) -> Void)?,
            onMapTapped: ((CLLocationCoordinate2D) -> Void)?,
            onMapLongPressed: ((CLLocationCoordinate2D) -> Void)?,
            onRoutePointDragged: ((Int, CLLocationCoordinate2D) -> Void)?,
            onMeasurementPointDragged: ((Int, CLLocationCoordinate2D) -> Void)?,
            onSelectionCornerDragged: ((Int, CLLocationCoordinate2D) -> Void)?
        ) {
            self.viewModel = viewModel
            self.onViewportChanged = onViewportChanged
            self.onPOISelected = onPOISelected
            self.onWaypointSelected = onWaypointSelected
            self.onMapTapped = onMapTapped
            self.onMapLongPressed = onMapLongPressed
            self.onRoutePointDragged = onRoutePointDragged
            self.onMeasurementPointDragged = onMeasurementPointDragged
            self.onSelectionCornerDragged = onSelectionCornerDragged
        }

        // MARK: - Tap Gesture

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard isDrawingMode || isMeasuringMode,
                  let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onMapTapped?(coordinate)
        }

        @objc func handleMapLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  !isDrawingMode, !isMeasuringMode, !isSelectingArea,
                  let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onMapLongPressed?(coordinate)
        }

        // MARK: - Gesture Recognizer Delegate

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // For the corner pan gesture: only begin if the touch is near a selection corner.
            // Returning false makes the gesture "fail", allowing the map's built-in pan
            // (which has require(toFail:) on this gesture) to proceed normally.
            if gestureRecognizer === cornerPanGesture {
                guard let mapView = gestureRecognizer.view as? MLNMapView else { return false }
                guard !selectionAnnotations.isEmpty else { return false }

                let touchPoint = gestureRecognizer.location(in: mapView)
                let hitRadius: CGFloat = 30

                for annotation in selectionAnnotations {
                    let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
                    let dx = touchPoint.x - annotationPoint.x
                    let dy = touchPoint.y - annotationPoint.y
                    if dx * dx + dy * dy < hitRadius * hitRadius {
                        draggingCornerIndex = annotation.index
                        return true
                    }
                }
                return false
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Never allow the corner pan gesture to fire simultaneously with any other pan.
            if gestureRecognizer === cornerPanGesture || otherGestureRecognizer === cornerPanGesture {
                return false
            }
            return true
        }

        // MARK: - Custom Corner Pan Gesture

        @objc func handleCornerPan(_ gesture: UIPanGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView,
                  let cornerIndex = draggingCornerIndex else { return }

            let touchPoint = gesture.location(in: mapView)
            let coord = mapView.convert(touchPoint, toCoordinateFrom: mapView)

            switch gesture.state {
            case .began:
                isDraggingSelection = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            case .changed:
                // Directly update the annotation's coordinate and rebuild the rectangle.
                // Since we own the gesture (not MapLibre's isDraggable), we have full
                // control over the coordinate -- no stale value issue.
                let sorted = selectionAnnotations.sorted { $0.index < $1.index }
                if cornerIndex < sorted.count {
                    sorted[cornerIndex].coordinate = coord
                }
                rebuildSelectionRect(on: mapView)

            case .ended, .cancelled:
                let sorted = selectionAnnotations.sorted { $0.index < $1.index }
                if cornerIndex < sorted.count {
                    sorted[cornerIndex].coordinate = coord
                }
                isDraggingSelection = false
                draggingCornerIndex = nil
                rebuildSelectionRect(on: mapView)
                onSelectionCornerDragged?(cornerIndex, coord)

            default:
                break
            }
        }

        // MARK: - Map Delegate

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            viewModel.currentZoom = mapView.zoomLevel
            viewModel.currentCenter = mapView.centerCoordinate
            viewModel.currentHeading = mapView.direction

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

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // After a style reload (base layer change or initial load), all
            // previously applied overlay layers are gone. Reset tracking and
            // reconcile with the desired state.
            appliedOverlays = []
            reconcileOverlays(with: style)
        }

        // MARK: - Overlay Layer Management

        func updateOverlays(on mapView: MLNMapView, enabled: Set<OverlayLayer>) {
            desiredOverlays = enabled
            reconcileOverlays(with: mapView.style)
        }

        private func reconcileOverlays(with style: MLNStyle?) {
            guard let style else { return }
            guard desiredOverlays != appliedOverlays else { return }

            let toRemove = appliedOverlays.subtracting(desiredOverlays)
            let toAdd = desiredOverlays.subtracting(appliedOverlays)

            for overlay in toRemove {
                removeOverlayLayer(overlay, from: style)
            }
            for overlay in toAdd {
                addOverlayLayer(overlay, to: style)
            }

            appliedOverlays = desiredOverlays
        }

        private func addOverlayLayer(_ overlay: OverlayLayer, to style: MLNStyle) {
            guard style.source(withIdentifier: overlay.sourceID) == nil else { return }

            let source = MLNRasterTileSource(
                identifier: overlay.sourceID,
                tileURLTemplates: [overlay.tileURL],
                options: [.tileSize: 256]
            )
            style.addSource(source)

            let layer = MLNRasterStyleLayer(identifier: overlay.layerID, source: source)
            layer.rasterOpacity = NSExpression(forConstantValue: 0.7)
            style.addLayer(layer)
        }

        private func removeOverlayLayer(_ overlay: OverlayLayer, from style: MLNStyle) {
            if let layer = style.layer(withIdentifier: overlay.layerID) {
                style.removeLayer(layer)
            }
            if let source = style.source(withIdentifier: overlay.sourceID) {
                style.removeSource(source)
            }
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            if annotation is SearchPinAnnotation {
                return searchPinView(for: annotation, on: mapView)
            }
            if let waypointAnnotation = annotation as? WaypointAnnotation {
                return waypointAnnotationView(for: waypointAnnotation, on: mapView)
            }
            if let poiAnnotation = annotation as? POIAnnotation {
                return poiAnnotationView(for: poiAnnotation, on: mapView)
            }
            if annotation is SelectionCornerAnnotation {
                return selectionCornerView(for: annotation, on: mapView)
            }
            if let measurePoint = annotation as? MeasurementPointAnnotation {
                return measurementPointView(for: measurePoint, on: mapView)
            }
            if let routePoint = annotation as? RoutePointAnnotation {
                return routePointView(for: routePoint, on: mapView)
            }
            return nil
        }

        func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            if let waypointAnnotation = annotation as? WaypointAnnotation {
                onWaypointSelected?(waypointAnnotation.waypoint)
            } else if let poiAnnotation = annotation as? POIAnnotation {
                onPOISelected?(poiAnnotation.poi)
            }
        }

        func mapView(
            _ mapView: MLNMapView,
            annotationView: MLNAnnotationView,
            didChange dragState: MLNAnnotationViewDragState,
            fromOldState oldState: MLNAnnotationViewDragState
        ) {
            // Selection corners are handled by handleCornerPan, not MapLibre's drag system.
            if dragState == .starting {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            guard let annotation = annotationView.annotation else { return }

            if dragState == .dragging {
                if annotation is RoutePointAnnotation {
                    rebuildDrawingPolyline(on: mapView)
                } else if annotation is MeasurementPointAnnotation {
                    rebuildMeasurementShape(on: mapView)
                }
            }

            guard dragState == .ending else { return }
            let newCoord = annotation.coordinate
            if let routePoint = annotation as? RoutePointAnnotation {
                onRoutePointDragged?(routePoint.index, newCoord)
            } else if let measurePoint = annotation as? MeasurementPointAnnotation {
                onMeasurementPointDragged?(measurePoint.index, newCoord)
            }
        }

        private func rebuildDrawingPolyline(on mapView: MLNMapView) {
            if let existing = drawingPolyline {
                mapView.removeAnnotation(existing)
                drawingPolyline = nil
            }
            let coords = drawingAnnotations.map { $0.coordinate }
            guard coords.count >= 2 else { return }
            var mutableCoords = coords
            let polyline = MLNPolyline(coordinates: &mutableCoords, count: UInt(coords.count))
            mapView.addAnnotation(polyline)
            drawingPolyline = polyline
        }

        private func rebuildMeasurementShape(on mapView: MLNMapView) {
            if let existing = measurementPolyline {
                mapView.removeAnnotation(existing)
                measurementPolyline = nil
            }
            if let existing = measurementPolygon {
                mapView.removeAnnotation(existing)
                measurementPolygon = nil
            }
            let coords = measurementAnnotations.map { $0.coordinate }
            guard !coords.isEmpty else { return }

            if currentMeasurementMode == .distance && coords.count >= 2 {
                var mutableCoords = coords
                let polyline = MLNPolyline(coordinates: &mutableCoords, count: UInt(coords.count))
                mapView.addAnnotation(polyline)
                measurementPolyline = polyline
            } else if currentMeasurementMode == .area && coords.count >= 3 {
                var closed = coords
                closed.append(coords[0])
                let polygon = MLNPolygon(coordinates: &closed, count: UInt(closed.count))
                mapView.addAnnotation(polygon)
                measurementPolygon = polygon
            }
        }

        private func rebuildSelectionRect(on mapView: MLNMapView) {
            if let existing = selectionPolygon {
                mapView.removeAnnotation(existing)
                selectionPolygon = nil
            }
            if let existing = selectionPolyline {
                mapView.removeAnnotation(existing)
                selectionPolyline = nil
            }

            guard selectionAnnotations.count == 4 else { return }
            let coords = selectionAnnotations.sorted { $0.index < $1.index }.map { $0.coordinate }

            var fillCorners = [coords[0], coords[1], coords[2], coords[3]]
            let polygon = MLNPolygon(coordinates: &fillCorners, count: 4)
            selectionPolygon = polygon
            mapView.addAnnotation(polygon)

            var borderCoords = [coords[0], coords[1], coords[2], coords[3], coords[0]]
            let polyline = MLNPolyline(coordinates: &borderCoords, count: 5)
            selectionPolyline = polyline
            mapView.addAnnotation(polyline)
        }

        func mapView(
            _ mapView: MLNMapView,
            strokeColorForShapeAnnotation annotation: MLNShape
        ) -> UIColor {
            if annotation === drawingPolyline {
                return UIColor(hex: "#3e4533")
            }
            if annotation === selectionPolygon || annotation === selectionPolyline {
                return UIColor(hex: "#3e4533")
            }
            if annotation === measurementPolyline || annotation === measurementPolygon {
                return .systemOrange
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
            if annotation === selectionPolyline { return 3 }
            if annotation === measurementPolyline { return 3 }
            return annotation === drawingPolyline ? 3 : 4
        }

        func mapView(
            _ mapView: MLNMapView,
            alphaForShapeAnnotation annotation: MLNShape
        ) -> CGFloat {
            if annotation === selectionPolygon { return 0.2 }
            if annotation === measurementPolygon { return 0.15 }
            if annotation === drawingPolyline { return 0.8 }
            if annotation === measurementPolyline { return 0.9 }
            return 0.9
        }

        func mapView(
            _ mapView: MLNMapView,
            fillColorForPolygonAnnotation annotation: MLNPolygon
        ) -> UIColor {
            if annotation === selectionPolygon { return UIColor(hex: "#3e4533") }
            if annotation === measurementPolygon { return .systemOrange }
            return UIColor(hex: "#3e4533")
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

        // MARK: - Waypoint Annotations

        func updateWaypointAnnotations(on mapView: MLNMapView, waypoints: [Waypoint]) {
            let newIds = Set(waypoints.map(\.id))
            guard newIds != currentWaypointIds else { return }

            let existing = mapView.annotations?.compactMap { $0 as? WaypointAnnotation } ?? []
            if !existing.isEmpty {
                mapView.removeAnnotations(existing)
            }

            let annotations = waypoints.map { WaypointAnnotation(waypoint: $0) }
            if !annotations.isEmpty {
                mapView.addAnnotations(annotations)
            }

            currentWaypointIds = newIds
        }

        // MARK: - Route Polylines

        func updateRoutePolylines(on mapView: MLNMapView, routes: [Route]) {
            let newIds = Set(routes.map(\.id))
            guard newIds != currentRouteIds else { return }

            // Remove old route polylines (exclude drawing, measurement, selection, and point annotations)
            let existingPolylines = mapView.annotations?.compactMap { annotation -> MLNPolyline? in
                guard let polyline = annotation as? MLNPolyline,
                      polyline !== drawingPolyline,
                      polyline !== measurementPolyline,
                      polyline !== selectionPolyline,
                      !(annotation is MLNPolygon),
                      !(annotation is POIAnnotation),
                      !(annotation is WaypointAnnotation),
                      !(annotation is RoutePointAnnotation),
                      !(annotation is MeasurementPointAnnotation),
                      !(annotation is SelectionCornerAnnotation) else { return nil }
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

        // MARK: - Selection Rectangle

        func updateSelectionRect(
            on mapView: MLNMapView,
            corner1: CLLocationCoordinate2D?,
            corner2: CLLocationCoordinate2D?
        ) {
            // Never touch anything while the user is actively dragging a corner.
            if isDraggingSelection { return }

            // If corners are nil, remove everything and return
            guard let c1 = corner1, let c2 = corner2 else {
                if let existing = selectionPolygon {
                    mapView.removeAnnotation(existing)
                    selectionPolygon = nil
                }
                if let existing = selectionPolyline {
                    mapView.removeAnnotation(existing)
                    selectionPolyline = nil
                }
                if !selectionAnnotations.isEmpty {
                    mapView.removeAnnotations(selectionAnnotations)
                    selectionAnnotations = []
                }
                return
            }

            let south = min(c1.latitude, c2.latitude)
            let north = max(c1.latitude, c2.latitude)
            let west = min(c1.longitude, c2.longitude)
            let east = max(c1.longitude, c2.longitude)

            let sw = CLLocationCoordinate2D(latitude: south, longitude: west)
            let nw = CLLocationCoordinate2D(latitude: north, longitude: west)
            let ne = CLLocationCoordinate2D(latitude: north, longitude: east)
            let se = CLLocationCoordinate2D(latitude: south, longitude: east)

            // If corner annotations already exist, update positions in-place.
            // This keeps the annotation objects stable.
            if selectionAnnotations.count == 4 {
                let newCoords = [sw, nw, ne, se]
                let sorted = selectionAnnotations.sorted { $0.index < $1.index }
                var changed = false
                for (annotation, coord) in zip(sorted, newCoords) {
                    if annotation.coordinate.latitude != coord.latitude
                        || annotation.coordinate.longitude != coord.longitude {
                        annotation.coordinate = coord
                        changed = true
                    }
                }
                if changed {
                    rebuildSelectionRect(on: mapView)
                }
                return
            }

            // First time: create polygon, polyline, and corner annotations
            var fillCorners = [sw, nw, ne, se]
            let polygon = MLNPolygon(coordinates: &fillCorners, count: 4)
            selectionPolygon = polygon
            mapView.addAnnotation(polygon)

            var borderCoords = [sw, nw, ne, se, sw]
            let polyline = MLNPolyline(coordinates: &borderCoords, count: 5)
            selectionPolyline = polyline
            mapView.addAnnotation(polyline)

            // Corner annotations: 0=SW, 1=NW, 2=NE, 3=SE
            // NOT draggable via MapLibre -- dragging is handled by cornerPanGesture.
            let cornerCoords = [sw, nw, ne, se]
            let corners = cornerCoords.enumerated().map { index, coord in
                SelectionCornerAnnotation(coordinate: coord, index: index)
            }
            mapView.addAnnotations(corners)
            selectionAnnotations = corners
        }

        // MARK: - Measurement Overlay

        func updateMeasurementOverlay(
            on mapView: MLNMapView,
            coordinates: [CLLocationCoordinate2D],
            mode: MeasurementMode?
        ) {
            // Remove old measurement elements
            if let existing = measurementPolyline {
                mapView.removeAnnotation(existing)
                measurementPolyline = nil
            }
            if let existing = measurementPolygon {
                mapView.removeAnnotation(existing)
                measurementPolygon = nil
            }
            if !measurementAnnotations.isEmpty {
                mapView.removeAnnotations(measurementAnnotations)
                measurementAnnotations = []
            }

            guard let mode, !coordinates.isEmpty else { return }

            // Add point markers
            let pointAnnotations = coordinates.enumerated().map { index, coord in
                MeasurementPointAnnotation(coordinate: coord, index: index)
            }
            mapView.addAnnotations(pointAnnotations)
            measurementAnnotations = pointAnnotations

            if mode == .distance && coordinates.count >= 2 {
                var mutableCoords = coordinates
                let polyline = MLNPolyline(
                    coordinates: &mutableCoords,
                    count: UInt(coordinates.count)
                )
                mapView.addAnnotation(polyline)
                measurementPolyline = polyline
            } else if mode == .area && coordinates.count >= 3 {
                // Close the polygon
                var closed = coordinates
                closed.append(coordinates[0])
                let polygon = MLNPolygon(
                    coordinates: &closed,
                    count: UInt(closed.count)
                )
                mapView.addAnnotation(polygon)
                measurementPolygon = polygon
            }
        }

        // MARK: - Search Pin

        func updateSearchPin(on mapView: MLNMapView, coordinate: CLLocationCoordinate2D?) {
            // Remove existing pin if coordinate changed or cleared
            if let existing = searchPinAnnotation {
                if let newCoord = coordinate,
                   existing.coordinate.latitude == newCoord.latitude,
                   existing.coordinate.longitude == newCoord.longitude {
                    return // Same pin, no update needed
                }
                mapView.removeAnnotation(existing)
                searchPinAnnotation = nil
            }

            guard let coordinate else { return }

            let pin = SearchPinAnnotation()
            pin.coordinate = coordinate
            mapView.addAnnotation(pin)
            searchPinAnnotation = pin
        }

        // MARK: - Annotation Views

        private func poiAnnotationView(
            for annotation: POIAnnotation,
            on mapView: MLNMapView
        ) -> MLNAnnotationView? {
            let reuseId = "poi-\(annotation.poi.category.rawValue)"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                let size: CGFloat = 32
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: size, height: size)

                let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circle.backgroundColor = UIColor(hex: annotation.poi.category.color)
                circle.layer.cornerRadius = size / 2
                circle.layer.borderWidth = 2
                circle.layer.borderColor = UIColor.white.cgColor
                circle.layer.shadowColor = UIColor.black.cgColor
                circle.layer.shadowOpacity = 0.3
                circle.layer.shadowOffset = CGSize(width: 0, height: 1)
                circle.layer.shadowRadius = 2
                view?.addSubview(circle)

                let iconSize: CGFloat = 15
                let image = UIImage(named: annotation.poi.category.iconName)?.withRenderingMode(.alwaysTemplate)
                let iconView = UIImageView(image: image)
                iconView.tintColor = .white
                iconView.contentMode = .scaleAspectFit
                iconView.frame = CGRect(
                    x: (size - iconSize) / 2,
                    y: (size - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                circle.addSubview(iconView)
            }

            return view
        }

        private func waypointAnnotationView(
            for annotation: WaypointAnnotation,
            on mapView: MLNMapView
        ) -> MLNAnnotationView? {
            let reuseId = "waypoint"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                let width: CGFloat = 28
                let height: CGFloat = 36
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: width, height: height)
                view?.centerOffset = CGVector(dx: 0, dy: -height / 2)

                let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
                let image = UIImage(systemName: "mappin.circle.fill", withConfiguration: config)?
                    .withTintColor(UIColor(hex: "#3e4533"), renderingMode: .alwaysOriginal)
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFit
                imageView.frame = CGRect(x: 0, y: 0, width: width, height: height)
                imageView.layer.shadowColor = UIColor.black.cgColor
                imageView.layer.shadowOpacity = 0.3
                imageView.layer.shadowOffset = CGSize(width: 0, height: 1)
                imageView.layer.shadowRadius = 2
                view?.addSubview(imageView)
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
                view?.isDraggable = true

                let dot = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
                dot.backgroundColor = UIColor(hex: "#3e4533")
                dot.layer.cornerRadius = 10
                dot.layer.borderWidth = 2
                dot.layer.borderColor = UIColor.white.cgColor
                view?.addSubview(dot)
            }

            return view
        }

        private func measurementPointView(
            for annotation: MeasurementPointAnnotation,
            on mapView: MLNMapView
        ) -> MLNAnnotationView? {
            let reuseId = "measurement-point"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                view?.isDraggable = true

                let dot = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
                dot.backgroundColor = .systemOrange
                dot.layer.cornerRadius = 10
                dot.layer.borderWidth = 2
                dot.layer.borderColor = UIColor.white.cgColor
                view?.addSubview(dot)
            }

            return view
        }

        private func selectionCornerView(
            for annotation: MLNAnnotation,
            on mapView: MLNMapView
        ) -> MLNAnnotationView? {
            let reuseId = "selection-corner"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
                // NOT isDraggable -- dragging is handled by our custom cornerPanGesture.
                // MapLibre's built-in drag system does not update annotation.coordinate
                // in real-time, which causes the rectangle lines to disconnect.

                let dot = UIView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
                dot.backgroundColor = UIColor(hex: "#3e4533")
                dot.layer.cornerRadius = 12
                dot.layer.borderWidth = 3
                dot.layer.borderColor = UIColor.white.cgColor
                dot.layer.shadowColor = UIColor.black.cgColor
                dot.layer.shadowOpacity = 0.3
                dot.layer.shadowOffset = CGSize(width: 0, height: 1)
                dot.layer.shadowRadius = 2
                view?.addSubview(dot)
            }

            // Disable user interaction on the corner view itself so touches
            // pass through to the map view where our pan gesture handles them.
            view?.isUserInteractionEnabled = false

            return view
        }

        private func searchPinView(
            for annotation: MLNAnnotation,
            on mapView: MLNMapView
        ) -> MLNAnnotationView? {
            let reuseId = "search-pin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)

            if view == nil {
                let width: CGFloat = 30
                let height: CGFloat = 40
                view = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view?.frame = CGRect(x: 0, y: 0, width: width, height: height)
                view?.centerOffset = CGVector(dx: 0, dy: -height / 2)

                let config = UIImage.SymbolConfiguration(pointSize: 34, weight: .medium)
                let image = UIImage(systemName: "mappin.circle.fill", withConfiguration: config)?
                    .withTintColor(UIColor(hex: "#3e4533"), renderingMode: .alwaysOriginal)
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFit
                imageView.frame = CGRect(x: 0, y: 0, width: width, height: height)
                imageView.layer.shadowColor = UIColor.black.cgColor
                imageView.layer.shadowOpacity = 0.3
                imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
                imageView.layer.shadowRadius = 4
                view?.addSubview(imageView)
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
