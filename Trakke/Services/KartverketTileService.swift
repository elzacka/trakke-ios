import Foundation
import OSLog

enum BaseLayer: String, CaseIterable, Identifiable, Sendable {
    case topo
    case grayscale
    case toporaster

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topo: return String(localized: "map.layer.topo")
        case .grayscale: return String(localized: "map.layer.grayscale")
        case .toporaster: return String(localized: "map.layer.toporaster")
        }
    }

    var tileURL: String {
        switch self {
        case .topo:
            return "https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png"
        case .grayscale:
            return "https://cache.kartverket.no/v1/wmts/1.0.0/topograatone/default/webmercator/{z}/{y}/{x}.png"
        case .toporaster:
            return "https://cache.kartverket.no/v1/wmts/1.0.0/toporaster/default/webmercator/{z}/{y}/{x}.png"
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
    case hillshading
    case naturvernomrader
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
        case .hillshading: return String(localized: "map.overlay.hillshading")
        case .naturvernomrader: return String(localized: "map.overlay.naturvernomrader")
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

    /// Minimum zoom level for the overlay source.
    var minZoom: Int {
        switch self {
        case .turrutebasen: return 5
        case .hillshading: return 3
        case .naturvernomrader: return 6
        case .naturskogFoer1940, .naturskogSannsynlighet, .naturskogNaerhet: return 8
        }
    }

    /// Raster opacity — hillshading needs enough opacity for visible 3D relief effect.
    var opacity: Double {
        switch self {
        case .hillshading: return 0.7
        case .naturvernomrader: return 0.5
        default: return 0.7
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
        case .hillshading:
            return "https://wms.geonorge.no/skwms1/wms.fjellskygge"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=fjellskygge&STYLES=default&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .naturvernomrader:
            return "https://kart.miljodirektoratet.no/arcgis/services/vern/mapserver/WMSServer"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=naturvern_omrade&STYLES=&SRS=EPSG:3857"
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
        case .turrutebasen, .hillshading: return "\u{00A9} Kartverket"
        case .naturvernomrader,
             .naturskogFoer1940, .naturskogSannsynlighet, .naturskogNaerhet:
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
        let fileName = "kartverket-style-\(layer.rawValue).json"
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let fileURL = cacheDir.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let data = styleJSON(for: layer)
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                Logger.map.error("Failed to write map style to cache: \(error, privacy: .private)")
            }
        }
        return fileURL
    }
}
