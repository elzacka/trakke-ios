import SwiftUI
@preconcurrency import MapLibre

// MARK: - Overlay Layer Management

extension TrakkeMapView.Coordinator {

    func updateOverlays(on mapView: MLNMapView, enabled: Set<OverlayLayer>) {
        desiredOverlays = enabled
        reconcileOverlays(with: mapView.style)
    }

    func reconcileOverlays(with style: MLNStyle?) {
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
        guard style.source(withIdentifier: overlay.sourceID) == nil,
              let tileURL = overlay.tileURL else { return }

        let source = MLNRasterTileSource(
            identifier: overlay.sourceID,
            tileURLTemplates: [tileURL],
            options: [
                .tileSize: 256,
                .minimumZoomLevel: overlay.minZoom,
                .maximumZoomLevel: overlay.maxZoom,
            ]
        )
        style.addSource(source)

        let layer = MLNRasterStyleLayer(identifier: overlay.layerID, source: source)
        layer.rasterOpacity = NSExpression(forConstantValue: overlay.opacity)
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
}
