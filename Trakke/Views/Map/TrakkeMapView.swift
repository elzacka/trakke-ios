import SwiftUI
@preconcurrency import MapLibre

// MARK: - Map View
// Annotation type definitions (POIAnnotation, WaypointAnnotation, RoutePointAnnotation, …)
// live in MapAnnotations.swift.

struct TrakkeMapView: UIViewRepresentable {
    @Bindable var viewModel: MapViewModel
    var pois: [POI] = []
    var routes: [Route] = []
    var activities: [Activity] = []
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
    var isNavigating = false
    var navigationCameraMode: NavigationCameraMode = .northUp
    var userHeading: Double?
    var compassDestination: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = KartverketTileService.styleURL(for: viewModel.baseLayer)
        let mapView = TrakkeMLNMapView(frame: .zero, styleURL: styleURL)

        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        // Brand-color the user-location puck (and its heading cone, when available).
        mapView.tintColor = UIColor(Color.Trakke.brand)
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
        // MapLibre's built-in compass kolliderer visuelt med app-en sin egen
        // "tilbakestill nord"-knapp i MapControlsOverlay. Hold den alltid skjult.
        mapView.compassView.compassVisibility = .hidden
        mapView.allowsRotating = enableRotation

        // Reset heading if requested
        if viewModel.shouldResetHeading {
            mapView.setDirection(0, animated: true)
            viewModel.shouldResetHeading = false
        }

        // Non-navigation heading mode: re-engage followWithHeading after user pans,
        // or disengage when toggled off. Navigation overrides this with its own logic.
        if !isNavigating {
            if viewModel.isHeadingUp {
                if !context.coordinator.isUserInteracting && mapView.userTrackingMode != .followWithHeading {
                    mapView.userTrackingMode = .followWithHeading
                }
            } else if mapView.userTrackingMode == .followWithHeading {
                mapView.userTrackingMode = .follow
            }
        }

        // Eksplisitt zoom-kommando fra zoom-knappene. Må fyres før
        // isUserInteracting-vakten under, ellers svelges trykket når en
        // annen kamera-animasjon (kompass-reset, centerOnUser, lokasjon-
        // tracking) holder flagget oppe.
        if let target = viewModel.pendingZoom {
            mapView.setZoomLevel(target, animated: true)
            viewModel.pendingZoom = nil
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
        // and MapLibre tracking is off (tracking handles centering itself).
        if !context.coordinator.isUserInteracting && mapView.userTrackingMode == .none {
            let vmCenter = viewModel.currentCenter
            let currentCenter = mapView.centerCoordinate
            let distance = Haversine.distance(from: currentCenter, to: vmCenter)

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

        // Update activity polylines (only visible activities)
        context.coordinator.updateActivityPolylines(on: mapView, activities: activities)

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

        // Update navigation compass rendering
        context.coordinator.updateNavigation(
            on: mapView,
            isNavigating: isNavigating,
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
        var draggingCornerIndex: Int?
        var draggingMeasurementIndex: Int?
        var draggingRouteIndex: Int?

        // Reusable haptic generators (avoids creating new instances per gesture)
        let lightHaptic = UIImpactFeedbackGenerator(style: .light)
        let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

        var currentPOIIds: Set<String> = []
        var currentWaypointIds: Set<String> = []
        var currentRouteIds: Set<String> = []
        var currentActivityIds: Set<String> = []
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
        var lastMeasurementCoordinates: [CLLocationCoordinate2D] = []
        var lastMeasurementMode: MeasurementMode?
        var searchPinAnnotation: SearchPinAnnotation?
        var navLayersActive = false
        var lastCompassUserLat: Double = 0
        var lastCompassUserLon: Double = 0
        var lastAppliedNavCameraMode: NavigationCameraMode?
        var compassDestinationAnnotation: NavigationDestinationAnnotation?

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

        // Gesture handlers live in TrakkeMapView+Gestures.swift.

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

        // Overlay layer management lives in TrakkeMapView+Overlays.swift.

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
            if annotation === drawingPolyline { return 3 }
            // Casing is 3pt wider than the coloured stroke so a 1.5pt rim shows
            // either side. Matches Knut/Monsen/Frej recommendation.
            if annotation is RouteHaloPolyline || annotation is ActivityHaloPolyline {
                return 7
            }
            return 4
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