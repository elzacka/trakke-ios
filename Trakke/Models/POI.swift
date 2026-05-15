import Foundation
import CoreLocation

// MARK: - POI Category

enum POICategory: String, CaseIterable, Identifiable, Sendable {
    case shelters
    case caves
    case viewpoints
    case warMemorials
    case wildernessShelters
    case kulturminner
    /// Konsolidert badeplass-kategori. Tidligere separate POI-typer
    /// (jettegryter, kroksjøer, laguner, varme kilder) er nå slått sammen
    /// — alle er i praksis steder folk bader.
    case swimmingSpot
    case firePit
    case waterfall
    case hammock
    case restStop
    case tentSite
    case cabins

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shelters: return String(localized: "poi.tilfluktsrom")
        case .caves: return String(localized: "poi.huler")
        case .viewpoints: return String(localized: "poi.utsiktspunkter")
        case .warMemorials: return String(localized: "poi.krigsminner")
        case .wildernessShelters: return String(localized: "poi.gapahuk")
        case .kulturminner: return String(localized: "poi.kulturminner")
        case .swimmingSpot: return String(localized: "poi.badeplasser")
        case .firePit: return String(localized: "poi.balplasser")
        case .waterfall: return String(localized: "poi.fosser")
        case .hammock: return String(localized: "poi.hengekoyeplasser")
        case .restStop: return String(localized: "poi.rasteplasser")
        case .tentSite: return String(localized: "poi.teltplasser")
        case .cabins: return String(localized: "poi.hytter")
        }
    }

    /// Ikonenavn — POI* refererer asset-katalog, øvrige er SF Symbols
    /// (resolveres via POIIconImage som faller tilbake til Image(systemName:)).
    var iconName: String {
        switch self {
        case .shelters: return "POITilfluktsrom"
        case .caves: return "POICave"
        case .viewpoints: return "POIViewpoint"
        case .warMemorials: return "POIMonument"
        case .wildernessShelters: return "POIShelter"
        case .kulturminner: return "POIHistoric"
        case .swimmingSpot: return "POISwimmingSpot"
        case .firePit: return "flame.fill"
        case .waterfall: return "POIWaterfall"
        case .hammock: return "POIHammock"
        case .restStop: return "POIPicnicTable"
        case .tentSite: return "tent.fill"
        case .cabins: return "POICabin"
        }
    }

    var color: String {
        switch self {
        case .shelters: return "#b58900"
        case .caves: return "#8b4513"
        case .viewpoints: return "#4a7c8a"
        case .warMemorials: return "#7b4a6b"
        case .wildernessShelters: return "#b45309"
        case .kulturminner: return "#6b5b8a"
        case .swimmingSpot: return "#147a8c"
        case .firePit: return "#d97706"
        case .waterfall: return "#2d8590"
        case .hammock: return "#6b8e23"
        case .restStop: return "#6b6b50"
        case .tentSite: return "#5a7d4a"
        case .cabins: return "#9c4a3c"
        }
    }

    var minZoom: Double {
        switch self {
        case .shelters: return 10
        case .caves: return 10
        case .viewpoints: return 11
        case .warMemorials: return 9
        case .wildernessShelters: return 10
        case .kulturminner: return 10
        case .swimmingSpot: return 10
        case .firePit: return 11
        case .waterfall: return 11
        case .hammock: return 10
        case .restStop: return 12          // 8964 features — krever høyere zoom for å unngå rot
        case .tentSite: return 11
        case .cabins: return 9
        }
    }

    var sourceName: String {
        switch self {
        case .shelters: return "DSB"
        case .caves, .viewpoints, .warMemorials, .wildernessShelters, .hammock:
            return "OpenStreetMap contributors"
        case .kulturminner: return "Riksantikvaren"
        case .swimmingSpot, .firePit, .restStop, .tentSite:
            return "UT.no/DNT, OpenStreetMap contributors"
        case .waterfall: return "Wikidata"
        case .cabins: return "UT.no/DNT, Statskog, fjellstyrer m.fl."
        }
    }

    var sourceLicense: String {
        switch self {
        case .shelters: return "NLOD 2.0"
        case .caves, .viewpoints, .warMemorials, .wildernessShelters,
             .swimmingSpot, .firePit, .hammock, .restStop, .tentSite: return "ODbL"
        case .kulturminner: return "NLOD 2.0"
        case .waterfall: return "CC0"
        case .cabins: return "ODbL / NLOD"
        }
    }

    var contentGroup: ContentGroup {
        switch self {
        case .shelters: return .beredskap
        case .caves, .wildernessShelters, .swimmingSpot, .firePit,
             .hammock, .restStop, .tentSite, .cabins: return .friluftsliv
        case .viewpoints, .waterfall: return .landskap
        case .warMemorials, .kulturminner: return .kulturarv
        }
    }

    /// Whether offline bundled data exists for this category.
    var isBundled: Bool {
        switch self {
        case .caves, .viewpoints, .warMemorials, .wildernessShelters, .shelters,
             .swimmingSpot, .firePit, .waterfall, .hammock,
             .restStop, .tentSite, .cabins:
            return true
        case .kulturminner: return false
        }
    }

    /// Whether this category should also refresh from a live API when online.
    var isLive: Bool {
        switch self {
        case .shelters, .kulturminner: return true
        case .caves, .viewpoints, .warMemorials, .wildernessShelters,
             .swimmingSpot, .firePit, .waterfall, .hammock,
             .restStop, .tentSite, .cabins:
            return false
        }
    }
}

// MARK: - POI Model

struct POI: Identifiable, Sendable, Equatable {
    let id: String
    let category: POICategory
    let name: String
    let coordinate: CLLocationCoordinate2D
    var details: [String: String] = [:]

    static func == (lhs: POI, rhs: POI) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Viewport Bounds

struct ViewportBounds: Sendable {
    let north: Double
    let south: Double
    let east: Double
    let west: Double

    var isValid: Bool {
        north > south && east > west &&
        (-90...90).contains(north) && (-90...90).contains(south) &&
        (-180...180).contains(east) && (-180...180).contains(west)
    }

    func buffered(factor: Double = 1.2) -> ViewportBounds {
        let latSpan = (north - south) * (factor - 1) / 2
        let lonSpan = (east - west) * (factor - 1) / 2
        return ViewportBounds(
            north: min(north + latSpan, 90),
            south: max(south - latSpan, -90),
            east: min(east + lonSpan, 180),
            west: max(west - lonSpan, -180)
        )
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= south && coordinate.latitude <= north &&
        coordinate.longitude >= west && coordinate.longitude <= east
    }

    var cacheKey: String {
        String(format: "%.4f,%.4f,%.4f,%.4f", north, south, east, west)
    }
}
