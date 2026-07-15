import SwiftUI
@preconcurrency import MapLibre

// MARK: - Gesture handlers

extension TrakkeMapView.Coordinator {

    // MARK: - Tap Gesture

    @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = gesture.view as? MLNMapView else { return }
        let point = gesture.location(in: mapView)

        // Hit-test mot tap-bare annotasjoner (POI, steder, søke-pin) —
        // MapLibre's didSelect:-mekanisme håndterer disse, og vi vil ikke
        // også fyre onMapTapped (som ville lukke et nyåpnet detalj-ark).
        let hitRadius: CGFloat = 22
        let hitRadiusSquared = hitRadius * hitRadius
        let tappableAnnotations: [MLNAnnotation] =
            Array(poiAnnotationMap.values)
            + Array(waypointAnnotationMap.values)
            + (searchPinAnnotation.map { [$0] } ?? [])
        for annotation in tappableAnnotations {
            let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
            let dx = point.x - annotationPoint.x
            let dy = point.y - annotationPoint.y
            if dx * dx + dy * dy < hitRadiusSquared {
                return
            }
        }

        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        // Haptisk feedback bare ved aktive tegne/måle-handlinger — tomme
        // tap i idle (for å lukke ark) skal være stille.
        if isDrawingMode || isMeasuringMode {
            lightHaptic.impactOccurred()
        }
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
            let hitRadius: CGFloat = 44

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
}
