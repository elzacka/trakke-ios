import SwiftUI
@preconcurrency import MapLibre

// MARK: - MapView Subclass

/// Prevents MapLibre from falling back to the deprecated
/// UIViewController.automaticallyAdjustsScrollViewInsets during layout.
/// Setting automaticallyAdjustsContentInset after super.init populates the
/// internal _automaticallyAdjustContentInsetHolder ivar, which makes
/// MapLibre's layout skip the deprecated VC property check entirely.
///
/// MapLibre 6.23.0 emits a one-time NSLog warning during init via
/// dispatch_once in commonInitWithOptions: (MLNMapView.mm:776-780). This
/// fires before super.init returns, so it cannot be suppressed from consumer
/// code. No MLNMapOptions, static method, or log-level setting can disable it.
/// The MapLibre team has a TODO to remove it but hasn't acted on it through
/// 6.23.1-pre1. The warning is cosmetic -- the subclass correctly prevents
/// the deprecated behavior from affecting layout.
private class TrakkeMLNMapView: MLNMapView {
    override init(frame: CGRect, styleURL: URL?) {
        super.init(frame: frame, styleURL: styleURL)
        self.automaticallyAdjustsContentInset = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
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

    // Offline pack boundaries
    var offlinePackBounds: [(south: Double, west: Double, north: Double, east: Double)] = []

    // Navigation
    var navigationRouteCoordinates: [CLLocationCoordinate2D] = []
    var navigationSegmentIndex: Int = 0
    var isNavigating = false
    var navigationCameraMode: NavigationCameraMode = .northUp
    var userHeading: Double?
    var compassDestination: CLLocationCoordinate2D?
    var navigationMode: NavigationMode = .route

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

        // Make the map's built-in pan gesture wait for our custom pan to fail first.
        // This prevents the map from scrolling when the user drags a point.
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

        // Center map on viewModel's current center/zoom — but only when
        // the user is NOT actively panning/zooming (prevents snap-back)
        if !context.coordinator.isUserInteracting {
            let vmCenter = viewModel.currentCenter
            let currentCenter = mapView.centerCoordinate
            let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
                .distance(from: CLLocation(latitude: vmCenter.latitude, longitude: vmCenter.longitude))

            if distance > 5 || abs(mapView.zoomLevel - viewModel.currentZoom) > 0.5 {
                mapView.setCenter(vmCenter, zoomLevel: viewModel.currentZoom, animated: true)
            }
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

        // Update offline pack boundaries
        context.coordinator.updateOfflineBounds(on: mapView, packBounds: offlinePackBounds)

        // Update navigation route/compass rendering
        context.coordinator.updateNavigation(
            on: mapView,
            coordinates: navigationRouteCoordinates,
            segmentIndex: navigationSegmentIndex,
            isNavigating: isNavigating,
            mode: navigationMode,
            compassDestination: compassDestination,
            cameraMode: navigationCameraMode,
            heading: userHeading
        )

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
    // MLNMapViewDelegate callbacks are dispatched on the main thread by MapLibre.
    // @MainActor isolation is required; @preconcurrency silences the Sendable warning
    // from the Obj-C MLNMapViewDelegate protocol which predates Swift concurrency.

    @MainActor class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate, UIGestureRecognizerDelegate {
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
        var lastOfflinePackBounds: [(south: Double, west: Double, north: Double, east: Double)] = []

        // Custom pan drag state for selection corners, measurement points, and route points.
        // Replaces MapLibre's isDraggable system which conflicts with our gesture setup.
        var cornerPanGesture: UIPanGestureRecognizer?
        var isDraggingSelection = false
        private var draggingCornerIndex: Int?
        private var draggingMeasurementIndex: Int?
        private var draggingRouteIndex: Int?

        // Reusable haptic generators (avoids creating new instances per gesture)
        private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
        private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

        var currentPOIIds: Set<String> = []
        var currentWaypointIds: Set<String> = []
        var currentRouteIds: Set<String> = []
        var poiAnnotationMap: [String: POIAnnotation] = [:]
        var waypointAnnotationMap: [String: WaypointAnnotation] = [:]
        var drawingPolyline: MLNPolyline?
        var drawingAnnotations: [RoutePointAnnotation] = []
        var selectionPolygon: MLNPolygon?
        var selectionPolyline: MLNPolyline?
        var selectionAnnotations: [SelectionCornerAnnotation] = []
        var measurementPolyline: MLNPolyline?
        var measurementPolygon: MLNPolygon?
        var measurementAnnotations: [MeasurementPointAnnotation] = []
        var searchPinAnnotation: SearchPinAnnotation?
        var navLayersActive = false
        var lastNavSegmentIndex = -1
        var lastNavCoordCount = 0
        var lastNavMode: NavigationMode?
        var lastCompassUserLat: Double = 0
        var lastCompassUserLon: Double = 0
        var lastCameraHeading: Double = -1

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
            lightHaptic.impactOccurred()
            onMapTapped?(coordinate)
        }

        @objc func handleMapLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  !isDrawingMode, !isMeasuringMode, !isSelectingArea,
                  let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            mediumHaptic.impactOccurred()
            onMapLongPressed?(coordinate)
        }

        // MARK: - Gesture Recognizer Delegate

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // For the custom pan gesture: begin if the touch is near any draggable point
            // (selection corner, measurement point, or route drawing point).
            // Returning false makes the gesture "fail", allowing the map's built-in pan to proceed.
            if gestureRecognizer === cornerPanGesture {
                guard let mapView = gestureRecognizer.view as? MLNMapView else { return false }
                let touchPoint = gestureRecognizer.location(in: mapView)
                let hitRadius: CGFloat = 30

                // Check selection corners
                for annotation in selectionAnnotations {
                    let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
                    let dx = touchPoint.x - annotationPoint.x
                    let dy = touchPoint.y - annotationPoint.y
                    if dx * dx + dy * dy < hitRadius * hitRadius {
                        draggingCornerIndex = annotation.index
                        return true
                    }
                }

                // Check measurement points
                for annotation in measurementAnnotations {
                    let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
                    let dx = touchPoint.x - annotationPoint.x
                    let dy = touchPoint.y - annotationPoint.y
                    if dx * dx + dy * dy < hitRadius * hitRadius {
                        draggingMeasurementIndex = annotation.index
                        return true
                    }
                }

                // Check route drawing points
                for annotation in drawingAnnotations {
                    let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
                    let dx = touchPoint.x - annotationPoint.x
                    let dy = touchPoint.y - annotationPoint.y
                    if dx * dx + dy * dy < hitRadius * hitRadius {
                        draggingRouteIndex = annotation.index
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

        // MARK: - Custom Point Drag Gesture

        @objc func handleCornerPan(_ gesture: UIPanGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            let touchPoint = gesture.location(in: mapView)
            let coord = mapView.convert(touchPoint, toCoordinateFrom: mapView)

            if let cornerIndex = draggingCornerIndex {
                handleSelectionCornerDrag(gesture, mapView: mapView, cornerIndex: cornerIndex, coord: coord)
            } else if let measureIndex = draggingMeasurementIndex {
                handleMeasurementPointDrag(gesture, mapView: mapView, pointIndex: measureIndex, coord: coord)
            } else if let routeIndex = draggingRouteIndex {
                handleRoutePointDrag(gesture, mapView: mapView, pointIndex: routeIndex, coord: coord)
            }
        }

        private func handleSelectionCornerDrag(
            _ gesture: UIPanGestureRecognizer,
            mapView: MLNMapView,
            cornerIndex: Int,
            coord: CLLocationCoordinate2D
        ) {
            let sorted = selectionAnnotations.sorted { $0.index < $1.index }
            switch gesture.state {
            case .began:
                isDraggingSelection = true
                mediumHaptic.impactOccurred()
            case .changed:
                if cornerIndex < sorted.count { sorted[cornerIndex].coordinate = coord }
                rebuildSelectionRect(on: mapView)
            case .ended, .cancelled:
                if cornerIndex < sorted.count { sorted[cornerIndex].coordinate = coord }
                isDraggingSelection = false
                draggingCornerIndex = nil
                rebuildSelectionRect(on: mapView)
                onSelectionCornerDragged?(cornerIndex, coord)
            default: break
            }
        }

        private func handleMeasurementPointDrag(
            _ gesture: UIPanGestureRecognizer,
            mapView: MLNMapView,
            pointIndex: Int,
            coord: CLLocationCoordinate2D
        ) {
            switch gesture.state {
            case .began:
                mediumHaptic.impactOccurred()
            case .changed:
                if pointIndex < measurementAnnotations.count {
                    measurementAnnotations[pointIndex].coordinate = coord
                }
                rebuildMeasurementShape(on: mapView)
            case .ended, .cancelled:
                if pointIndex < measurementAnnotations.count {
                    measurementAnnotations[pointIndex].coordinate = coord
                }
                draggingMeasurementIndex = nil
                rebuildMeasurementShape(on: mapView)
                onMeasurementPointDragged?(pointIndex, coord)
            default: break
            }
        }

        private func handleRoutePointDrag(
            _ gesture: UIPanGestureRecognizer,
            mapView: MLNMapView,
            pointIndex: Int,
            coord: CLLocationCoordinate2D
        ) {
            switch gesture.state {
            case .began:
                mediumHaptic.impactOccurred()
            case .changed:
                if pointIndex < drawingAnnotations.count {
                    drawingAnnotations[pointIndex].coordinate = coord
                }
                rebuildDrawingPolyline(on: mapView)
            case .ended, .cancelled:
                if pointIndex < drawingAnnotations.count {
                    drawingAnnotations[pointIndex].coordinate = coord
                }
                draggingRouteIndex = nil
                rebuildDrawingPolyline(on: mapView)
                onRoutePointDragged?(pointIndex, coord)
            default: break
            }
        }

        // MARK: - Map Delegate

        /// True while the user is actively panning/zooming the map.
        /// Prevents updateUIView from snapping the map back to the old center.
        var isUserInteracting = false

        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            isUserInteracting = false
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

            // Navigation layers are gone after style reload; reset so
            // the next updateUIView cycle recreates them.
            navLayersActive = false

            // Reapply offline pack boundaries after style reload.
            if !lastOfflinePackBounds.isEmpty {
                updateOfflineBounds(on: mapView, packBounds: lastOfflinePackBounds)
            }
        }

        // MARK: - Overlay Layer Management

        func updateOverlays(on mapView: MLNMapView, enabled: Set<OverlayLayer>) {
            desiredOverlays = enabled
            reconcileOverlays(with: mapView.style)
        }

        private func reconcileOverlays(with style: MLNStyle?) {
            guard let style else { return }

            // Verify applied overlays actually exist in the style.
            // If a style reload happened without going through didFinishLoading
            // (e.g., fullScreenCover dismiss), layers may be gone but tracking stale.
            let stale = appliedOverlays.filter { style.layer(withIdentifier: $0.layerID) == nil }
            if !stale.isEmpty {
                appliedOverlays.subtract(stale)
            }

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
            if overlay == .hillshading {
                addHillshadeLayer(to: style)
                return
            }

            guard style.source(withIdentifier: overlay.sourceID) == nil else { return }

            let source = MLNRasterTileSource(
                identifier: overlay.sourceID,
                tileURLTemplates: [overlay.tileURL],
                options: [
                    .tileSize: 256,
                    .minimumZoomLevel: overlay.minZoom,
                    .maximumZoomLevel: 18,
                ]
            )
            style.addSource(source)

            let layer = MLNRasterStyleLayer(identifier: overlay.layerID, source: source)
            layer.rasterOpacity = NSExpression(forConstantValue: overlay.opacity)
            style.addLayer(layer)
        }

        private func removeOverlayLayer(_ overlay: OverlayLayer, from style: MLNStyle) {
            if overlay == .hillshading {
                removeHillshadeLayer(from: style)
                return
            }

            if let layer = style.layer(withIdentifier: overlay.layerID) {
                style.removeLayer(layer)
            }
            if let source = style.source(withIdentifier: overlay.sourceID) {
                style.removeSource(source)
            }
        }

        // MARK: - Client-Side DEM Hillshade

        private func addHillshadeLayer(to style: MLNStyle) {
            guard style.source(withIdentifier: TerrainConstants.demSourceID) == nil else { return }

            let demSource = MLNRasterDEMSource(
                identifier: TerrainConstants.demSourceID,
                tileURLTemplates: [TerrainConstants.demTileURL],
                options: [
                    .tileSize: 256,
                    .minimumZoomLevel: MapConstants.minZoom,
                    .maximumZoomLevel: TerrainConstants.maxDEMZoom,
                    .demEncoding: NSNumber(value: MLNDEMEncoding.terrarium.rawValue),
                ]
            )
            style.addSource(demSource)

            let hillshade = MLNHillshadeStyleLayer(
                identifier: TerrainConstants.hillshadeLayerID,
                source: demSource
            )
            hillshade.hillshadeExaggeration = NSExpression(
                forConstantValue: NSNumber(value: TerrainConstants.defaultExaggeration)
            )
            hillshade.hillshadeIlluminationDirection = NSExpression(
                forConstantValue: NSNumber(value: TerrainConstants.defaultIlluminationDirection)
            )
            hillshade.hillshadeIlluminationAnchor = NSExpression(
                forConstantValue: "viewport"
            )
            hillshade.hillshadeShadowColor = NSExpression(
                forConstantValue: UIColor(white: 0.0, alpha: 0.8)
            )
            hillshade.hillshadeAccentColor = NSExpression(
                forConstantValue: UIColor(white: 0.0, alpha: 0.15)
            )

            if let baseLayer = style.layer(withIdentifier: viewModel.baseLayer.layerID) {
                style.insertLayer(hillshade, above: baseLayer)
            } else {
                style.addLayer(hillshade)
            }
        }

        private func removeHillshadeLayer(from style: MLNStyle) {
            if let layer = style.layer(withIdentifier: TerrainConstants.hillshadeLayerID) {
                style.removeLayer(layer)
            }
            if let source = style.source(withIdentifier: TerrainConstants.demSourceID) {
                style.removeSource(source)
            }
        }


        // Note: MapLibre's built-in annotation drag (didChange dragState) is not used.
        // All point dragging is handled by our custom pan gesture (handleCornerPan)
        // which avoids gesture conflicts with the map's scroll pan.


        func mapView(
            _ mapView: MLNMapView,
            strokeColorForShapeAnnotation annotation: MLNShape
        ) -> UIColor {
            if annotation === drawingPolyline {
                return UIColor.Trakke.brand
            }
            if annotation === selectionPolygon || annotation === selectionPolyline {
                return UIColor.Trakke.brand
            }
            if annotation === measurementPolyline || annotation === measurementPolygon {
                return UIColor.Trakke.measurement
            }
            if let polyline = annotation as? MLNPolyline, let colorHex = polyline.title {
                return UIColor(hex: colorHex)
            }
            return UIColor.Trakke.brand
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
            if annotation === selectionPolygon { return UIColor.Trakke.brand }
            if annotation === measurementPolygon { return UIColor.Trakke.measurement }
            return UIColor.Trakke.brand
        }



    }
}