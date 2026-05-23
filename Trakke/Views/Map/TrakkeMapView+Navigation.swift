import CoreLocation
@preconcurrency import MapLibre

// MARK: - Navigation Destination Annotation

/// Pin shown at the user's chosen destination in compass mode so the dashed
/// line ends in something visible rather than empty terrain.
final class NavigationDestinationAnnotation: NSObject, MLNAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { String(localized: "navigation.destinationLabel") }

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

// MARK: - Navigation Rendering

extension TrakkeMapView.Coordinator {

    // MARK: - Navigation Layer IDs

    private static let navRemainingSrcID = "nav-remaining-src"
    private static let navRemainingCasingLyrID = "nav-remaining-casing-lyr"
    private static let navRemainingLyrID = "nav-remaining-lyr"
    private static let navWalkedSrcID = "nav-walked-src"
    private static let navWalkedCasingLyrID = "nav-walked-casing-lyr"
    private static let navWalkedLyrID = "nav-walked-lyr"
    private static let navArrowsLyrID = "nav-arrows-lyr"
    private static let navCompassSrcID = "nav-compass-src"
    private static let navCompassLyrID = "nav-compass-lyr"
    private static let navArrowIcon = "nav-arrow-icon"

    func updateNavigation(
        on mapView: MLNMapView,
        coordinates: [CLLocationCoordinate2D],
        segmentIndex: Int,
        isNavigating: Bool,
        mode: NavigationMode,
        compassDestination: CLLocationCoordinate2D?,
        cameraMode: NavigationCameraMode,
        heading: Double?
    ) {
        guard let style = mapView.style else { return }

        if !isNavigating {
            if navLayersActive {
                clearAllNavLayers(from: style)
                clearCompassDestinationPin(from: mapView)
                navLayersActive = false
                lastNavSegmentIndex = -1
                lastNavCoordCount = 0
                lastNavMode = nil
                lastCompassUserLat = 0
                lastCompassUserLon = 0
                lastCameraHeading = -1
            }
            // Restore default camera state when navigation ends.
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

        // Register arrow icon if not already present in this style
        if style.image(forName: Self.navArrowIcon) == nil {
            style.setImage(createNavArrowIcon(), forName: Self.navArrowIcon)
        }

        // Check if rendering needs an update
        let needsRender = !navLayersActive
            || lastNavMode != mode
            || lastNavSegmentIndex != segmentIndex
            || lastNavCoordCount != coordinates.count

        switch mode {
        case .route:
            if lastNavMode == .compass {
                clearCompassNavLayers(from: style)
                clearCompassDestinationPin(from: mapView)
            }
            if needsRender {
                renderRouteNavigation(
                    style: style,
                    coordinates: coordinates,
                    segmentIndex: segmentIndex
                )
            }
        case .compass:
            if lastNavMode == .route { clearRouteNavLayers(from: style) }
            if let userCoord = viewModel.userLocation?.coordinate,
               let dest = compassDestination {
                // Only re-render compass line when user moved >5m
                let latDelta = userCoord.latitude - lastCompassUserLat
                let lonDelta = userCoord.longitude - lastCompassUserLon
                let movedSignificantly = !navLayersActive
                    || lastNavMode != mode
                    || (latDelta * latDelta + lonDelta * lonDelta) > 2e-9 // ~5m
                if movedSignificantly {
                    renderCompassNavigation(style: style, from: userCoord, to: dest)
                    lastCompassUserLat = userCoord.latitude
                    lastCompassUserLon = userCoord.longitude
                }
                updateCompassDestinationPin(on: mapView, at: dest)
            } else {
                clearCompassDestinationPin(from: mapView)
            }
        }

        lastNavMode = mode
        lastNavSegmentIndex = segmentIndex
        lastNavCoordCount = coordinates.count

        // Camera control: delegate to MapLibre's userTrackingMode so the map
        // re-centers (and rotates, in courseUp) automatically as the user moves.
        // Only re-apply when the cameraMode actually changes — that way a pan
        // gesture (which silently sets userTrackingMode to .none) is respected.
        if cameraMode != lastAppliedNavCameraMode {
            switch cameraMode {
            case .courseUp:
                mapView.userTrackingMode = .followWithHeading
            case .northUp:
                mapView.userTrackingMode = .follow
                if mapView.direction != 0 {
                    mapView.setDirection(0, animated: true)
                }
            }
            lastAppliedNavCameraMode = cameraMode
        }

        navLayersActive = true
    }

    // MARK: - Compass Destination Pin

    private func updateCompassDestinationPin(
        on mapView: MLNMapView,
        at coordinate: CLLocationCoordinate2D
    ) {
        if let existing = compassDestinationAnnotation {
            // MapLibre observes coordinate changes via KVO when declared @objc dynamic.
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

    private func renderRouteNavigation(
        style: MLNStyle,
        coordinates: [CLLocationCoordinate2D],
        segmentIndex: Int
    ) {
        guard coordinates.count >= 2 else {
            clearRouteNavLayers(from: style)
            return
        }

        let clampedIndex = min(segmentIndex, coordinates.count - 1)
        let walkedCoords = Array(coordinates[0...clampedIndex])
        let remainingCoords = Array(coordinates[clampedIndex...])

        // Remaining route (bright, with direction arrows)
        if remainingCoords.count >= 2 {
            var mutable = remainingCoords
            let line = MLNPolylineFeature(
                coordinates: &mutable,
                count: UInt(mutable.count)
            )

            if let source = style.source(withIdentifier: Self.navRemainingSrcID)
                as? MLNShapeSource {
                source.shape = line
            } else {
                let source = MLNShapeSource(
                    identifier: Self.navRemainingSrcID,
                    shape: line,
                    options: nil
                )
                style.addSource(source)

                // White casing first (renders below) for max contrast on
                // Kartverket topo. Design-system spec: 1.5pt casing each side
                // → 5pt colored stroke + 3pt total → 8pt casing.
                let casing = MLNLineStyleLayer(
                    identifier: Self.navRemainingCasingLyrID,
                    source: source
                )
                casing.lineColor = NSExpression(forConstantValue: UIColor.Trakke.mapHalo)
                casing.lineWidth = NSExpression(forConstantValue: 8)
                casing.lineOpacity = NSExpression(forConstantValue: 0.95)
                casing.lineCap = NSExpression(forConstantValue: "round")
                casing.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(casing)

                let layer = MLNLineStyleLayer(
                    identifier: Self.navRemainingLyrID,
                    source: source
                )
                layer.lineColor = NSExpression(forConstantValue: UIColor.Trakke.mapRoute)
                layer.lineWidth = NSExpression(forConstantValue: 5)
                layer.lineOpacity = NSExpression(forConstantValue: 0.95)
                layer.lineCap = NSExpression(forConstantValue: "round")
                layer.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(layer)

                let arrows = MLNSymbolStyleLayer(
                    identifier: Self.navArrowsLyrID,
                    source: source
                )
                arrows.symbolPlacement = NSExpression(forConstantValue: "line")
                arrows.symbolSpacing = NSExpression(forConstantValue: 80)
                arrows.iconImageName = NSExpression(forConstantValue: Self.navArrowIcon)
                arrows.iconRotationAlignment = NSExpression(forConstantValue: "map")
                arrows.iconAllowsOverlap = NSExpression(forConstantValue: true)
                style.addLayer(arrows)
            }
        } else {
            removeLayersAndSource(
                from: style,
                layerIDs: [Self.navRemainingLyrID, Self.navArrowsLyrID],
                sourceID: Self.navRemainingSrcID
            )
        }

        // Walked route (dimmed)
        if walkedCoords.count >= 2 {
            var mutable = walkedCoords
            let line = MLNPolylineFeature(
                coordinates: &mutable,
                count: UInt(mutable.count)
            )

            if let source = style.source(withIdentifier: Self.navWalkedSrcID)
                as? MLNShapeSource {
                source.shape = line
            } else {
                let source = MLNShapeSource(
                    identifier: Self.navWalkedSrcID,
                    shape: line,
                    options: nil
                )
                style.addSource(source)

                // Dimmed casing + dimmed amber: still visible on topo, but
                // visually demoted vs the upcoming-route layer ahead.
                let casing = MLNLineStyleLayer(
                    identifier: Self.navWalkedCasingLyrID,
                    source: source
                )
                casing.lineColor = NSExpression(forConstantValue: UIColor.Trakke.mapHalo)
                casing.lineWidth = NSExpression(forConstantValue: 7)
                casing.lineOpacity = NSExpression(forConstantValue: 0.6)
                casing.lineCap = NSExpression(forConstantValue: "round")
                casing.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(casing)

                let layer = MLNLineStyleLayer(
                    identifier: Self.navWalkedLyrID,
                    source: source
                )
                layer.lineColor = NSExpression(forConstantValue: UIColor.Trakke.mapRoute)
                layer.lineWidth = NSExpression(forConstantValue: 4)
                layer.lineOpacity = NSExpression(forConstantValue: 0.45)
                layer.lineCap = NSExpression(forConstantValue: "round")
                layer.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(layer)
            }
        } else {
            removeLayersAndSource(
                from: style,
                layerIDs: [Self.navWalkedLyrID],
                sourceID: Self.navWalkedSrcID
            )
        }
    }

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
            layer.lineColor = NSExpression(forConstantValue: UIColor.Trakke.mapRoute)
            layer.lineWidth = NSExpression(forConstantValue: 4)
            layer.lineOpacity = NSExpression(forConstantValue: 0.9)
            layer.lineDashPattern = NSExpression(forConstantValue: [2, 4])
            layer.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(layer)
        }
    }

    private func clearAllNavLayers(from style: MLNStyle) {
        clearRouteNavLayers(from: style)
        clearCompassNavLayers(from: style)
    }

    private func clearRouteNavLayers(from style: MLNStyle) {
        removeLayersAndSource(
            from: style,
            layerIDs: [Self.navArrowsLyrID, Self.navRemainingLyrID, Self.navRemainingCasingLyrID],
            sourceID: Self.navRemainingSrcID
        )
        removeLayersAndSource(
            from: style,
            layerIDs: [Self.navWalkedLyrID, Self.navWalkedCasingLyrID],
            sourceID: Self.navWalkedSrcID
        )
    }

    private func clearCompassNavLayers(from style: MLNStyle) {
        removeLayersAndSource(
            from: style,
            layerIDs: [Self.navCompassLyrID],
            sourceID: Self.navCompassSrcID
        )
    }

    private func removeLayersAndSource(
        from style: MLNStyle,
        layerIDs: [String],
        sourceID: String
    ) {
        for layerID in layerIDs {
            if let layer = style.layer(withIdentifier: layerID) {
                style.removeLayer(layer)
            }
        }
        if let source = style.source(withIdentifier: sourceID) {
            style.removeSource(source)
        }
    }

    private func createNavArrowIcon() -> UIImage {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 3, y: 1))
            path.addLine(to: CGPoint(x: 9, y: 6))
            path.addLine(to: CGPoint(x: 3, y: 11))
            UIColor.white.setStroke()
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}
