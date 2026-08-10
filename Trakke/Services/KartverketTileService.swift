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
    case naturvernomrader
    case naturskog
    case bratthetskart
    case utmRunenett
    case svekketIs
    case kvikkleire
    case eiendomsgrenser
    case ferdselsforbud
    case innsjodybde
    case snoskredAktsomhet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turrutebasen: return String(localized: "map.overlay.turrutebasen")
        case .naturvernomrader: return String(localized: "map.overlay.naturvernomrader")
        case .naturskog: return String(localized: "map.overlay.naturskog")
        case .bratthetskart: return String(localized: "map.overlay.bratthetskart")
        case .utmRunenett: return String(localized: "map.overlay.utmRunenett")
        case .svekketIs: return String(localized: "map.overlay.svekketIs")
        case .kvikkleire: return String(localized: "map.overlay.kvikkleire")
        case .eiendomsgrenser: return String(localized: "map.overlay.eiendomsgrenser")
        case .ferdselsforbud: return String(localized: "map.overlay.ferdselsforbud")
        case .innsjodybde: return String(localized: "map.overlay.innsjodybde")
        case .snoskredAktsomhet: return String(localized: "map.overlay.snoskredAktsomhet")
        }
    }

    var attribution: String {
        switch self {
        case .turrutebasen, .utmRunenett, .eiendomsgrenser:
            return "\u{00A9} Kartverket"
        case .naturvernomrader, .naturskog, .ferdselsforbud:
            return "\u{00A9} Milj\u{00F8}direktoratet"
        case .bratthetskart, .svekketIs, .kvikkleire, .innsjodybde, .snoskredAktsomhet:
            return "\u{00A9} NVE"
        }
    }

    var sourceID: String { "overlay-\(rawValue)" }
    var layerID: String { "overlay-\(rawValue)-layer" }

    /// UserDefaults-nøkkelen bryteren lagres under. Eksplisitt switch slik at
    /// nøkkelstrengene forblir byte-identiske for brukere som alt har dem satt.
    var storageKey: String {
        switch self {
        case .turrutebasen: return AppStorageKeys.overlayTurrutebasen
        case .naturvernomrader: return AppStorageKeys.overlayNaturvernomrader
        case .naturskog: return AppStorageKeys.overlayNaturskog
        case .bratthetskart: return AppStorageKeys.overlayBratthetskart
        case .utmRunenett: return AppStorageKeys.overlayUtmRunenett
        case .svekketIs: return AppStorageKeys.overlaySvekketIs
        case .kvikkleire: return AppStorageKeys.overlayKvikkleire
        case .eiendomsgrenser: return AppStorageKeys.overlayEiendomsgrenser
        case .ferdselsforbud: return AppStorageKeys.overlayFerdselsforbud
        case .innsjodybde: return AppStorageKeys.overlayInnsjodybde
        case .snoskredAktsomhet: return AppStorageKeys.overlaySnoskredAktsomhet
        }
    }

    /// Forhåndsvisning i kartlag-velgeren. Genereres av
    /// Scripts/generate_overlay_thumbnails.swift.
    var thumbnailAssetName: String { "overlay-thumb-\(rawValue)" }

    /// ArcGIS REST MapServer for "Skog etablert før 1940, ikke flatehogd"
    /// (layer ID 1 i naturskog_v1/MapServer).
    private static let naturskogRESTBase =
        "https://image001.miljodirektoratet.no/arcgis/rest/services"
        + "/naturskog/naturskog_v1/MapServer/export"

    // Merk for nye lag: WMS-tjenester med MaxScaleDenominator tegner ingenting
    // før flisskalaen (≈ 559 082 264 / 2^z i Mercator) er under grensen –
    // minZoom settes til første ikke-tomme zoomnivå.
    var minZoom: Int {
        switch self {
        case .turrutebasen: return 5
        case .naturvernomrader: return 6
        case .naturskog: return 8
        case .bratthetskart: return 9
        case .utmRunenett: return 7
        case .svekketIs: return 8
        case .kvikkleire: return 8
        case .eiendomsgrenser: return 14
        case .ferdselsforbud: return 7
        case .innsjodybde: return 12
        // Detaljlaget tegner ingenting før z13, målt i Romsdalen,
        // Jotunheimen og Lyngen. Tjenestens skalahint (1:75 595) tilsier
        // z12, men flisene er tomme der.
        case .snoskredAktsomhet: return 13
        }
    }

    var maxZoom: Int {
        switch self {
        case .bratthetskart: return 16
        default: return 18
        }
    }

    var opacity: Double {
        switch self {
        case .naturvernomrader: return 0.5
        case .bratthetskart, .eiendomsgrenser: return 0.9
        case .utmRunenett, .svekketIs, .snoskredAktsomhet: return 0.8
        case .kvikkleire: return 0.6
        default: return 0.7
        }
    }

    var tileURL: String? {
        switch self {
        case .turrutebasen:
            return "https://wms.geonorge.no/skwms1/wms.friluftsruter2"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=Fotrute&STYLES=default&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .naturvernomrader:
            // kart.miljodirektoratet.no sluttet å svare sommeren 2026 –
            // wms.miljodirektoratet.no er nytt vertsnavn for samme tjeneste.
            return "https://wms.miljodirektoratet.no/arcgis/services/vern/MapServer/WMSServer"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=naturvern_omrade&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .naturskog:
            return Self.naturskogRESTBase
                + "?bbox={bbox-epsg-3857}&bboxSR=3857&imageSR=3857"
                + "&size=256,256&format=png32&transparent=true"
                + "&layers=show:1&f=image"
        case .bratthetskart:
            // NVE la ned nve.geodataonline.no våren 2026. WMTS-cached XYZ-tiles på
            // gis3.nve.no er nå offisielt endepunkt og betraktelig raskere enn WMS.
            // ArcGIS-konvensjonen er tile/{z}/{y}/{x} (rad før kolonne).
            return "https://gis3.nve.no/arcgis/rest/services/wmts/Bratthet_2024"
                + "/MapServer/tile/{z}/{y}/{x}"
        case .utmRunenett:
            return "https://wms.geonorge.no/skwms1/wms.rutenett"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=10km_rutelinje,1km_rutelinje&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=TRUE"
        case .svekketIs:
            // NVE iskart: normal midtvintersituasjon, ikke dagsferske isforhold.
            // _N1000-oversiktslagene dekker z8–10, detaljlagene tar over fra ~z11.
            // SvekketIsIkkeVurdert er bevisst utelatt (støy uten faresignal).
            return "https://kart.nve.no/enterprise/services/SvekketIs1/MapServer/WMSServer"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=SvekketIs,SvekketIsElv,OppsprukketIsLangsLand"
                + ",SvekketIs_N1000,OppsprukketIsLangsLand_N1000"
                + "&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .kvikkleire:
            // NVE faresonekart (gradert rød/oransje/gul). Valgt over det
            // landsdekkende aktsomhetskartet, som er ugradert screening for
            // arealplanlegging og ville dekket store flater (2026-08-09).
            return "https://kart.nve.no/enterprise/services/SkredKvikkleire2/MapServer/WMSServer"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=KvikkleireFaregrad&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .eiendomsgrenser:
            // wms.matrikkelkart er den åpne av Kartverkets tre matrikkel-WMS-er
            // (wms.matrikkel og wms.matrikkel.v1 krever Norge digitalt-avtale).
            // Laget tegner først ved skala < 1:40 000 – derav minZoom 14.
            return "https://wms.geonorge.no/skwms1/wms.matrikkelkart"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=eiendomsgrense&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .ferdselsforbud:
            // Samme nye Miljødirektoratet-vert som vern-laget (kart.* døde
            // sommeren 2026). Geometrien har ingen sesongattributt – selve
            // forbudsperioden står i den enkelte verneforskriften.
            return "https://wms.miljodirektoratet.no/arcgis/services"
                + "/vern_restriksjonsomrader/MapServer/WMSServer"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=ferdselsforbud&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .snoskredAktsomhet:
            // Aktsomhetskart snøskred (NGIs metode fra 2023, forvaltet av NVE):
            // potensielle løsne- og utløpsområder på oversiktsnivå.
            //
            // Tjenesten har tre varianter knyttet til sikkerhetsklassene i NVEs
            // retningslinjer «Flaum- og skredfare i arealplanar»: én for S3 og to
            // for S2, med og uten skogens dempende effekt. S3 er valgt fordi det er
            // den videste utstrekningen – målt via ArcGIS REST på samme utsnitt i
            // Romsdalen: S3 1051 km², S2 uten skog 945 km², S2 med skog 916 km².
            // Spørsmålet en som går i terrenget har, er «kan et skred nå hit», og
            // da er den videste utstrekningen det riktige svaret. Pikselmåling
            // duger ikke til å avgjøre dette: lagene er skravert med ulik tetthet,
            // så S3 dekker færre piksler enn S2 selv om arealet er større.
            //
            // Oversiktslaget `PotensieltSkredfareOmr` (z8–12) er bevisst *ikke*
            // med: det er en heldekkende rgb(255,127,127) over 85 % av flisen, og
            // ville vasket ut kartet på planleggingsnivå uten å si noe nytt.
            return "https://kart.nve.no/enterprise/services/SnoskredAktsomhet/MapServer/WMSServer"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                + "&LAYERS=S3_snoskred_Aktsomhetsomrade&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        case .innsjodybde:
            // NVE Innsjødatabasen: ~600 av 243 000 innsjøer har dybdedata.
            // Lagene tegner først ved skala < 1:151 191 – derav minZoom 12.
            return "https://kart.nve.no/enterprise/services/Innsjodatabase2/MapServer/WMSServer"
                + "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
                // DybdePunkt er dybdetallene, det eneste laget du kan lese en
                // faktisk dybde av. Målt på Mjøsa, Tyrifjorden og Femunden:
                // alle tre lagene slår inn på z12 (tjenestens skalagrense er
                // 1:151 191, som tilsvarer z11,9), så minZoom 12 er riktig.
                // Dybdetallene er spredte – de fantes i Tyrifjorden, ikke i
                // Mjøsa eller Femunden.
                + "&LAYERS=Innsjo_ved_dybdemaling,DybdeKurve,DybdePunkt&STYLES=&SRS=EPSG:3857"
                + "&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256"
                + "&FORMAT=image/png&TRANSPARENT=true"
        }
    }
}

enum MapConstants {
    static let defaultCenter = (longitude: 10.7522, latitude: 59.9139) // Oslo
    static let defaultZoom: Double = 10
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
        // Use rawValue (stable across launches) instead of hashValue (randomised per
        // process in Swift 4.2+, which defeats the cache and litters the Caches dir).
        let styleVersion = 1
        let fileName = "kartverket-style-\(layer.rawValue)-v\(styleVersion).json"
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
