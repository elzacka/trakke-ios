import CoreLocation
@preconcurrency import MapLibre

// MARK: - Navigation Rendering

extension TrakkeMapView.Coordinator {

    // MARK: - Navigation Layer IDs

    private static let navRemainingSrcID = "nav-remaining-src"
    private static let navRemainingLyrID = "nav-remaining-lyr"
    private static let navWalkedSrcID = "nav-walked-src"
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
                navLayersActive = false
                lastNavSegmentIndex = -1
                lastNavCoordCount = 0
                lastNavMode = nil
                lastCompassUserLat = 0
                lastCompassUserLon = 0
                lastCameraHeading = -1
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
            if lastNavMode == .compass { clearCompassNavLayers(from: style) }
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
            }
        }

        lastNavMode = mode
        lastNavSegmentIndex = segmentIndex
        lastNavCoordCount = coordinates.count

        // Camera control -- only update when heading changed significantly
        switch cameraMode {
        case .courseUp:
            if let heading {
                var headingDelta = abs(heading - lastCameraHeading)
                if headingDelta > 180 { headingDelta = 360 - headingDelta }
                if lastCameraHeading < 0 || headingDelta >= 1.0 {
                    mapView.setDirection(heading, animated: true)
                    lastCameraHeading = heading
                }
            }
        case .northUp:
            if mapView.direction != 0 {
                mapView.setDirection(0, animated: true)
                lastCameraHeading = 0
            }
        }

        navLayersActive = true
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

                let layer = MLNLineStyleLayer(
                    identifier: Self.navRemainingLyrID,
                    source: source
                )
                layer.lineColor = NSExpression(forConstantValue: UIColor.Trakke.brand)
                layer.lineWidth = NSExpression(forConstantValue: 5)
                layer.lineOpacity = NSExpression(forConstantValue: 0.9)
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

                let layer = MLNLineStyleLayer(
                    identifier: Self.navWalkedLyrID,
                    source: source
                )
                layer.lineColor = NSExpression(forConstantValue: UIColor.Trakke.brand)
                layer.lineWidth = NSExpression(forConstantValue: 4)
                layer.lineOpacity = NSExpression(forConstantValue: 0.3)
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
            layer.lineColor = NSExpression(forConstantValue: UIColor.Trakke.brand)
            layer.lineWidth = NSExpression(forConstantValue: 3)
            layer.lineOpacity = NSExpression(forConstantValue: 0.7)
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
            layerIDs: [Self.navArrowsLyrID, Self.navRemainingLyrID],
            sourceID: Self.navRemainingSrcID
        )
        removeLayersAndSource(
            from: style,
            layerIDs: [Self.navWalkedLyrID],
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
