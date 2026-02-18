import Foundation
import CoreLocation

// MARK: - POI Category

enum POICategory: String, CaseIterable, Identifiable, Sendable {
    case shelters
    case caves
    case observationTowers
    case warMemorials
    case wildernessShelters
    case kulturminner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shelters: return String(localized: "poi.tilfluktsrom")
        case .caves: return String(localized: "poi.huler")
        case .observationTowers: return String(localized: "poi.observasjonstarn")
        case .warMemorials: return String(localized: "poi.krigsminner")
        case .wildernessShelters: return String(localized: "poi.gapahuk")
        case .kulturminner: return String(localized: "poi.kulturminner")
        }
    }

    var iconName: String {
        switch self {
        case .shelters: return "POITilfluktsrom"
        case .caves: return "POICave"
        case .observationTowers: return "POIObservationTower"
        case .warMemorials: return "POIMonument"
        case .wildernessShelters: return "POIShelter"
        case .kulturminner: return "POIHistoric"
        }
    }

    var color: String {
        switch self {
        case .shelters: return "#fbbf24"
        case .caves: return "#8b4513"
        case .observationTowers: return "#4a5568"
        case .warMemorials: return "#6b7280"
        case .wildernessShelters: return "#b45309"
        case .kulturminner: return "#8b7355"
        }
    }

    var minZoom: Double {
        switch self {
        case .shelters: return 10
        case .caves: return 10
        case .observationTowers: return 9
        case .warMemorials: return 9
        case .wildernessShelters: return 10
        case .kulturminner: return 6
        }
    }

    var sourceName: String {
        switch self {
        case .shelters: return "DSB"
        case .caves, .observationTowers, .warMemorials, .wildernessShelters:
            return "\u{00A9} OpenStreetMap contributors"
        case .kulturminner: return "Riksantikvaren"
        }
    }

    var sourceLicense: String {
        switch self {
        case .shelters: return "NLOD 2.0"
        case .caves, .observationTowers, .warMemorials, .wildernessShelters: return "ODbL"
        case .kulturminner: return "NLOD 2.0"
        }
    }

    var isBundled: Bool {
        switch self {
        case .caves, .observationTowers, .warMemorials, .wildernessShelters: return true
        case .shelters, .kulturminner: return false
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
