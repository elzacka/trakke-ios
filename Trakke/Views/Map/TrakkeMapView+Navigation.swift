import CoreLocation
@preconcurrency import MapLibre

// MARK: - Navigation Destination Annotation

/// Pin vist ved brukerens valgte destinasjon i kompass-modus.
final class NavigationDestinationAnnotation: NSObject, MLNAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { String(localized: "navigation.destinationLabel") }

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

// MARK: - Navigation Rendering

extension TrakkeMapView.Coordinator {

    // MARK: - Layer IDs

    private static let navCompassSrcID = "nav-compass-src"
    private static let navCompassLyrID = "nav-compass-lyr"

    func updateNavigation(
        on mapView: MLNMapView,
        isNavigating: Bool,
        compassDestination: CLLocationCoordinate2D?,
        cameraMode: NavigationCameraMode,
        heading: Double?
    ) {
        guard let style = mapView.style else { return }

        if !isNavigating {
            desiredNavCameraMode = nil
            if navLayersActive {
                clearCompassNavLayers(from: style)
                clearCompassDestinationPin(from: mapView)
                navLayersActive = false
                lastCompassUserLat = 0
                lastCompassUserLon = 0
            }
            if lastAppliedNavCameraMode != nil {
                if mapView.userTrackingMode != .none {
                    mapView.userTrackingMode = .none
                }
                if mapView.direction != 0 {
                    mapView.setDirection(0, animated: true)
                }
                lastAppliedNavCameraMode = nil
            }
            return
        }

        if let userCoord = viewModel.userLocation?.coordinate,
           let dest = compassDestination {
            let latDelta = userCoord.latitude - lastCompassUserLat
            let lonDelta = userCoord.longitude - lastCompassUserLon
            let movedSignificantly = !navLayersActive
                || (latDelta * latDelta + lonDelta * lonDelta) > 2e-9  // ~5m
            if movedSignificantly {
                renderCompassNavigation(style: style, from: userCoord, to: dest)
                lastCompassUserLat = userCoord.latitude
                lastCompassUserLon = userCoord.longitude
            }
            updateCompassDestinationPin(on: mapView, at: dest)
        } else {
            clearCompassDestinationPin(from: mapView)
        }

        // Re-apply tracking when mode changed explicitly, or when MapLibre
        // reset userTrackingMode to .none after a user gesture (zoom/pan).
        // Guard on !isUserInteracting so we don't fight an active gesture.
        desiredNavCameraMode = cameraMode
        let desiredTracking: MLNUserTrackingMode = cameraMode == .courseUp ? .followWithHeading : .follow
        let modeChangedExplicitly = cameraMode != lastAppliedNavCameraMode
        let trackingWasReset = !isUserInteracting && mapView.userTrackingMode != desiredTracking

        if modeChangedExplicitly || trackingWasReset {
            applyNavTracking(on: mapView, mode: cameraMode)
        }

        navLayersActive = true
    }

    /// Setter MapLibre-tracking for gitt navigasjonskameramodus. Kalles fra
    /// updateUIView OG fra regionDidChangeAnimated (gest-slutt) – updateUIView
    /// alene er ikke nok, siden den bare kjøres ved observert state-endring,
    /// som kan utebli når brukeren står stille etter gesten.
    func applyNavTracking(on mapView: MLNMapView, mode: NavigationCameraMode) {
        switch mode {
        case .courseUp:
            mapView.userTrackingMode = .followWithHeading
        case .northUp:
            mapView.userTrackingMode = .follow
            if mapView.direction != 0 {
                mapView.setDirection(0, animated: true)
            }
        }
        lastAppliedNavCameraMode = mode
    }

    // MARK: - Kompass-destinasjons-pin

    private func updateCompassDestinationPin(
        on mapView: MLNMapView,
        at coordinate: CLLocationCoordinate2D
    ) {
        if let existing = compassDestinationAnnotation {
            if existing.coordinate.latitude != coordinate.latitude
                || existing.coordinate.longitude != coordinate.longitude {
                existing.coordinate = coordinate
            }
            return
        }
        let annotation = NavigationDestinationAnnotation(coordinate: coordinate)
        mapView.addAnnotation(annotation)
        compassDestinationAnnotation = annotation
    }

    private func clearCompassDestinationPin(from mapView: MLNMapView) {
        if let annotation = compassDestinationAnnotation {
            mapView.removeAnnotation(annotation)
            compassDestinationAnnotation = nil
        }
    }

    // MARK: - Kompass-linje-rendering

    private func renderCompassNavigation(
        style: MLNStyle,
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) {
        var coords = [origin, destination]
        let line = MLNPolylineFeature(coordinates: &coords, count: 2)

        if let source = style.source(withIdentifier: Self.navCompassSrcID)
            as? MLNShapeSource {
            source.shape = line
        } else {
            let source = MLNShapeSource(
                identifier: Self.navCompassSrcID,
                shape: line,
                options: nil
            )
            style.addSource(source)

            let layer = MLNLineStyleLayer(
                identifier: Self.navCompassLyrID,
                source: source
            )
            layer.lineColor = NSExpression(forConstantValue: UIColor.Trakke.mapNavLine)
            layer.lineWidth = NSExpression(forConstantValue: 4)
            layer.lineOpacity = NSExpression(forConstantValue: 0.9)
            layer.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(layer)
        }
    }

    private func clearCompassNavLayers(from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: Self.navCompassLyrID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: Self.navCompassSrcID) {
            style.removeSource(source)
        }
    }
}
