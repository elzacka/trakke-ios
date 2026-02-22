import UIKit
@preconcurrency import MapLibre

// MARK: - Annotation Management & View Factories

extension TrakkeMapView.Coordinator {

    // MARK: - Annotation Delegate

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

    // MARK: - POI Annotations

    func updateAnnotations(on mapView: MLNMapView, pois: [POI]) {
        let newIds = Set(pois.map(\.id))
        guard newIds != currentPOIIds else { return }

        let toRemoveIds = currentPOIIds.subtracting(newIds)
        let toAddIds = newIds.subtracting(currentPOIIds)

        if !toRemoveIds.isEmpty {
            let toRemove = toRemoveIds.compactMap { poiAnnotationMap[$0] }
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }
            for id in toRemoveIds {
                poiAnnotationMap.removeValue(forKey: id)
            }
        }

        if !toAddIds.isEmpty {
            let poisToAdd = pois.filter { toAddIds.contains($0.id) }
            let annotations = poisToAdd.map { POIAnnotation(poi: $0) }
            mapView.addAnnotations(annotations)
            for annotation in annotations {
                poiAnnotationMap[annotation.poi.id] = annotation
            }
        }

        currentPOIIds = newIds
    }

    // MARK: - Waypoint Annotations

    func updateWaypointAnnotations(on mapView: MLNMapView, waypoints: [Waypoint]) {
        let newIds = Set(waypoints.map(\.id))
        guard newIds != currentWaypointIds else { return }

        let toRemoveIds = currentWaypointIds.subtracting(newIds)
        let toAddIds = newIds.subtracting(currentWaypointIds)

        if !toRemoveIds.isEmpty {
            let toRemove = toRemoveIds.compactMap { waypointAnnotationMap[$0] }
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }
            for id in toRemoveIds {
                waypointAnnotationMap.removeValue(forKey: id)
            }
        }

        if !toAddIds.isEmpty {
            let waypointsToAdd = waypoints.filter { toAddIds.contains($0.id) }
            let annotations = waypointsToAdd.map { WaypointAnnotation(waypoint: $0) }
            mapView.addAnnotations(annotations)
            for annotation in annotations {
                waypointAnnotationMap[annotation.waypoint.id] = annotation
            }
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

    // MARK: - Rebuild Helpers

    func rebuildDrawingPolyline(on mapView: MLNMapView) {
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

    func rebuildMeasurementShape(on mapView: MLNMapView) {
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

    func rebuildSelectionRect(on mapView: MLNMapView) {
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

    // MARK: - Annotation View Factories

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
                .withTintColor(UIColor.Trakke.brand, renderingMode: .alwaysOriginal)
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
            dot.backgroundColor = UIColor.Trakke.brand
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
            dot.backgroundColor = UIColor.Trakke.measurement
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
            dot.backgroundColor = UIColor.Trakke.brand
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
                .withTintColor(UIColor.Trakke.brand, renderingMode: .alwaysOriginal)
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
