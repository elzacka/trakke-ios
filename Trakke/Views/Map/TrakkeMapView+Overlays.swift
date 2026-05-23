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
        if overlay == .hillshading {
            addHillshadeLayer(to: style)
            return
        }

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
        // MapLibre 6.24+ added multidirectional hillshade. illuminationDirection,
        // shadowColor and highlightColor now accept arrays (one entry per light
        // source). Passing a scalar triggers `-[__NSCFNumber count]` / similar
        // crashes when the layer renders. Accent color stays scalar.
        hillshade.hillshadeIlluminationDirection = NSExpression(
            forConstantValue: [NSNumber(value: TerrainConstants.defaultIlluminationDirection)]
        )
        hillshade.hillshadeIlluminationAnchor = NSExpression(
            forConstantValue: "viewport"
        )
        hillshade.hillshadeShadowColor = NSExpression(
            forConstantValue: [UIColor(white: 0.0, alpha: 0.8)]
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
}
