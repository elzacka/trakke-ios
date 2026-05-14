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
    case swimmingSpot
    case firePit
    case waterfall
    case hammock
    case giantKettle
    case oxbowLake
    case lagoon
    case restStop
    case tentSite
    case hotSpring

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
        case .giantKettle: return String(localized: "poi.jettegryter")
        case .oxbowLake: return String(localized: "poi.kroksjoer")
        case .lagoon: return String(localized: "poi.laguner")
        case .restStop: return String(localized: "poi.rasteplasser")
        case .tentSite: return String(localized: "poi.teltplasser")
        case .hotSpring: return String(localized: "poi.varmeKilder")
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
        case .waterfall: return "drop.fill"
        case .hammock: return "POIHammock"
        case .giantKettle: return "circle.fill"
        case .oxbowLake: return "water.waves"
        case .lagoon: return "water.waves"
        case .restStop: return "chair.fill"
        case .tentSite: return "tent.fill"
        case .hotSpring: return "flame.circle.fill"
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
        case .giantKettle: return "#8b7355"
        case .oxbowLake: return "#3b6e8c"
        case .lagoon: return "#5fa8c4"
        case .restStop: return "#6b6b50"
        case .tentSite: return "#5a7d4a"
        case .hotSpring: return "#c23a34"
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
        case .giantKettle: return 11
        case .oxbowLake: return 11
        case .lagoon: return 11
        case .restStop: return 12          // 8964 features — krever høyere zoom for å unngå rot
        case .tentSite: return 11
        case .hotSpring: return 10
        }
    }

    var sourceName: String {
        switch self {
        case .shelters: return "DSB"
        case .caves, .viewpoints, .warMemorials, .wildernessShelters,
             .hammock, .giantKettle, .oxbowLake, .lagoon, .hotSpring:
            return "OpenStreetMap contributors"
        case .kulturminner: return "Riksantikvaren"
        case .swimmingSpot, .firePit, .restStop, .tentSite:
            return "UT.no/DNT, OpenStreetMap contributors"
        case .waterfall: return "Wikidata"
        }
    }

    var sourceLicense: String {
        switch self {
        case .shelters: return "NLOD 2.0"
        case .caves, .viewpoints, .warMemorials, .wildernessShelters,
             .swimmingSpot, .firePit, .hammock, .giantKettle,
             .oxbowLake, .lagoon, .restStop, .tentSite, .hotSpring: return "ODbL"
        case .kulturminner: return "NLOD 2.0"
        case .waterfall: return "CC0"
        }
    }

    var contentGroup: ContentGroup {
        switch self {
        case .shelters: return .beredskap
        case .caves, .wildernessShelters, .swimmingSpot, .firePit,
             .hammock, .restStop, .tentSite: return .friluftsliv
        case .viewpoints, .waterfall, .giantKettle, .oxbowLake,
             .lagoon, .hotSpring: return .landskap
        case .warMemorials, .kulturminner: return .kulturarv
        }
    }

    /// Whether offline bundled data exists for this category.
    var isBundled: Bool {
        switch self {
        case .caves, .viewpoints, .warMemorials, .wildernessShelters, .shelters,
             .swimmingSpot, .firePit, .waterfall, .hammock, .giantKettle,
              .oxbowLake, .lagoon, .restStop, .tentSite, .hotSpring:
            return true
        case .kulturminner: return false
        }
    }

    /// Whether this category should also refresh from a live API when online.
    var isLive: Bool {
        switch self {
        case .shelters, .kulturminner: return true
        case .caves, .viewpoints, .warMemorials, .wildernessShelters,
             .swimmingSpot, .firePit, .waterfall, .hammock, .giantKettle,
              .oxbowLake, .lagoon, .restStop, .tentSite, .hotSpring:
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
