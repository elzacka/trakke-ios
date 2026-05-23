import SwiftUI
@preconcurrency import MapLibre

// MARK: - MapView Subclass

/// Prevents MapLibre from falling back to the deprecated
/// UIViewController.automaticallyAdjustsScrollViewInsets during layout.
/// Setting automaticallyAdjustsContentInset after super.init populates the
/// internal _automaticallyAdjustContentInsetHolder ivar, which makes
/// MapLibre's layout skip the deprecated VC property check entirely.
///
/// MapLibre 6.26.0 still emits a one-time NSLog warning during init via
/// dispatch_once in commonInitWithOptions: (MLNMapView.mm:776-780). This
/// fires before super.init returns, so it cannot be suppressed from consumer
/// code. No MLNMapOptions, static method, or log-level setting can disable it.
/// The MapLibre team has a TODO to remove it but had not acted on it through
/// 6.26.0. The warning is cosmetic -- the subclass correctly prevents
/// the deprecated behavior from affecting layout.
final class TrakkeMLNMapView: MLNMapView {
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

// MARK: - Indexed Point Annotations

class IndexedPointAnnotation: MLNPointAnnotation {
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

final class RoutePointAnnotation: IndexedPointAnnotation {}
final class MeasurementPointAnnotation: IndexedPointAnnotation {}
final class SelectionCornerAnnotation: IndexedPointAnnotation {}

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

// MARK: - Activity Polyline

/// MLNPolyline subclass used so route-polyline refresh logic can skip these
/// (and vice versa) by type check instead of pointer identity.
class ActivityPolyline: MLNPolyline {}

/// Wider white polyline rendered UNDERNEATH a coloured route/activity polyline
/// to lift it visually off the Kartverket topographic background. Cartographer
/// consensus (Knut/Monsen/Frej): a white casing is essential for legibility on
/// any topographic map where the foreground line might compete with vegetation,
/// trail symbols or contour lines.
class RouteHaloPolyline: MLNPolyline {}
class ActivityHaloPolyline: MLNPolyline {}
