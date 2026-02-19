import Foundation

enum BaseLayer: String, CaseIterable, Identifiable, Sendable {
    case topo
    case grayscale

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topo: return String(localized: "map.layer.topo")
        case .grayscale: return String(localized: "map.layer.grayscale")
        }
    }

    var tileURL: String {
        switch self {
        case .topo:
            return "https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png"
        case .grayscale:
            return "https://cache.kartverket.no/v1/wmts/1.0.0/topograatone/default/webmercator/{z}/{y}/{x}.png"
        }
    }

    var sourceID: String {
        "kartverket-\(rawValue)"
    }

    var layerID: String {
        "kartverket-\(rawValue)-layer"
    }
}

enum OverlayLayer: String, CaseIterable, Identifiable, Sendable {
    case turrutebasen
    case naturskogFoer1940
    case naturskogSannsynlighet
    case naturskogNaerhet

    var id: String { rawValue }

    static var naturskogLayers: [OverlayLayer] {
        [.naturskogFoer1940, .naturskogSannsynlighet, .naturskogNaerhet]
    }

    var isNaturskog: Bool {
        Self.naturskogLayers.contains(self)
    }

    var displayName: String {
        switch self {
        case .turrutebasen: return String(localized: "map.overlay.turrutebasen")
        case .naturskogFoer1940: return String(localized: "map.overlay.naturskog.foer1940")
        case .naturskogSannsynlighet: return String(localized: "map.overlay.naturskog.sannsynlighet")
        case .naturskogNaerhet: return String(localized: "map.overlay.naturskog.naerhet")
        }
    }

    var sourceID: String { "overlay-\(rawValue)" }
    var layerID: String { "overlay-\(rawValue)-layer" }

    private static let naturskogRESTBase =
        "https://image001.miljodirektoratet.no/arcgis/rest/services"
        + "/naturskog/naturskog_v1/MapServer/export"

    /// ArcGIS REST layer IDs (from MapServer metadata):
    /// 1 = skog_etablert_foer_1940_ikke_flatehogd
    /// 2 = naturskogssannsynlighet
    /// 3 = naturskogsnaerhet
    private var naturskogLayerID: Int {
        switch self {
        case .naturskogFoer1940: return 1
        case .naturskogSannsynlighet: return 2
        case .naturskogNaerhet: return 3
        default: return 0
        }
    }

    var tileURL: String {
        switch self {
        case .turrutebasen:
            return "https://wms.geonorge.no/skwms1/wms.friluftsruter2"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=Fotrute&STYLES=default&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .naturskogFoer1940, .naturskogSannsynlighet, .naturskogNaerhet:
            return Self.naturskogRESTBase
                + "?bbox={bbox-epsg-3857}&bboxSR=3857&imageSR=3857"
                + "&size=256,256&format=png32&transparent=true"
                + "&layers=show:\(naturskogLayerID)&f=image"
        }
    }

    var attribution: String {
        switch self {
        case .turrutebasen: return "\u{00A9} Kartverket"
        case .naturskogFoer1940, .naturskogSannsynlighet, .naturskogNaerhet:
            return "\u{00A9} Milj\u{00F8}direktoratet"
        }
    }
}

enum MapConstants {
    static let defaultCenter = (longitude: 10.7522, latitude: 59.9139) // Oslo
    static let defaultZoom: Double = 10
    static let defaultPitch: Double = 0
    static let maxZoom: Double = 18
    static let minZoom: Double = 3
    static let maxPitch: Double = 85
    static let tileSize: Int = 256
    static let attribution = "\u{00A9} Kartverket"
}

enum KartverketTileService {
    static func styleJSON(for layer: BaseLayer) -> Data {
        let json: [String: Any] = [
            "version": 8,
            "name": "Kartverket \(layer.rawValue)",
            "sources": [
                layer.sourceID: [
                    "type": "raster",
                    "tiles": [layer.tileURL],
                    "tileSize": MapConstants.tileSize,
                    "minzoom": Int(MapConstants.minZoom),
                    "maxzoom": Int(MapConstants.maxZoom),
                    "attribution": MapConstants.attribution,
                ] as [String: Any]
            ],
            "layers": [
                [
                    "id": layer.layerID,
                    "type": "raster",
                    "source": layer.sourceID,
                ] as [String: Any]
            ],
        ]
        // The JSON structure is fully static and known-valid, so failure is not expected.
        // Using a do/catch to avoid a force unwrap in production.
        do {
            return try JSONSerialization.data(withJSONObject: json)
        } catch {
            // Fallback: return a minimal valid MapLibre style as empty JSON
            return Data("{}".utf8)
        }
    }

    static func styleURL(for layer: BaseLayer) -> URL {
        let data = styleJSON(for: layer)
        let fileName = "kartverket-style-\(layer.rawValue).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
        return fileURL
    }
}
