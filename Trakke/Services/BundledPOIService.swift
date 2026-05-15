import Foundation
import CoreLocation
import OSLog

// MARK: - Bundled POI Service

/// Loads pre-bundled GeoJSON POI data from the app bundle and filters by viewport.
/// Used for static OSM data (caves, observation towers, war memorials, wilderness shelters)
/// that rarely changes and doesn't need live API fetching.
@MainActor
enum BundledPOIService {
    private static var cache: [POICategory: [POI]] = [:]

    static func pois(for category: POICategory, in bounds: ViewportBounds) -> [POI] {
        let all = cache[category] ?? []
        return all.filter { bounds.contains($0.coordinate) }
    }

    /// Pre-load all bundled categories into the cache. Call once at app launch.
    static func preloadAll() {
        Task.detached(priority: .utility) {
            let allCategories: [POICategory] = [
                .caves, .viewpoints, .warMemorials, .wildernessShelters, .shelters,
                .swimmingSpot, .firePit, .waterfall, .hammock,
                .restStop, .tentSite, .cabins,
            ]
            for category in allCategories {
                let pois = loadFromBundle(category)
                await MainActor.run {
                    cache[category] = pois
                    Logger.poi.debug("BundledPOI: loaded \(pois.count, privacy: .public) \(category.rawValue, privacy: .public) from bundle")
                }
            }
        }
    }

    /// Load a single category if not yet cached.
    static func loadIfNeeded(_ category: POICategory) async {
        if cache[category] != nil { return }
        let pois = await Task.detached(priority: .utility) {
            loadFromBundle(category)
        }.value
        cache[category] = pois
        Logger.poi.debug("BundledPOI: loaded \(pois.count, privacy: .public) \(category.rawValue, privacy: .public) from bundle")
    }

    static func clearCache() {
        cache.removeAll()
    }

    // MARK: - Loading

    private nonisolated static func loadFromBundle(_ category: POICategory) -> [POI] {
        // Konsolidert badeplass: alle naturlige badesteder samles under én
        // kategori. swimming_spots inneholder eksplisitte badeplasser, mens
        // jettegryter, kroksjøer, laguner og varme kilder er steder som i
        // praksis brukes til bading.
        let filenames: [POICategory: [String]] = [
            .caves: ["caves"],
            .viewpoints: ["viewpoints"],
            .warMemorials: ["war_memorials"],
            .wildernessShelters: ["wilderness_shelters"],
            .shelters: ["shelters"],
            .swimmingSpot: ["swimming_spots", "giant_kettles", "oxbow_lakes", "lagoons", "hot_springs"],
            .firePit: ["fire_pits"],
            .waterfall: ["waterfalls"],
            .hammock: ["hammocks"],
            .restStop: ["rest_areas"],
            .tentSite: ["tent_sites"],
            // Hytter: DNT-hytter og andre hytter (Statskog, fjellstyrer, kommuner, private).
            // provider-feltet injiseres i enrich() for å skille kildene i popup.
            .cabins: ["dnt_hytter", "andre_hytter"],
        ]
        guard let names = filenames[category] else { return [] }
        return names.flatMap { loadFile(named: $0, category: category) }
    }

    private nonisolated static func loadFile(named filename: String, category: POICategory) -> [POI] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson", subdirectory: "POIData")
                ?? Bundle.main.url(forResource: filename, withExtension: "geojson") else {
            Logger.poi.error("BundledPOI: \(filename, privacy: .public).geojson not found in bundle")
            return []
        }
        let pois = decodePOIs(from: url, category: category)
        return enrich(pois, fromFile: filename)
    }

    /// Konsoliderte kategorier (badeplasser, hytter) inneholder POI-er fra
    /// flere kildefiler. Filnavnet er det eneste signalet vi har på *hva
    /// slags* underkategori det er — vi tagger derfor hver POI med en
    /// klassifikasjon her, og normaliserer/luker ut tekst som ellers ville
    /// vist seg dårlig i popup.
    private nonisolated static func enrich(_ pois: [POI], fromFile filename: String) -> [POI] {
        let subtype = subtypeKey(forFile: filename)
        let provider = providerKey(forFile: filename)
        let englishNoise: Set<String> = ["giants kettle", "oxbow lake", "lagoon", "hot spring"]
        let needsEnrichment = subtype != nil
            || provider != nil
            || filename == "giant_kettles"
            || filename == "andre_hytter"
        guard needsEnrichment else { return pois }
        return pois.map { poi in
            var enriched = poi
            if let subtype { enriched.details["subtype"] = subtype }
            if let provider { enriched.details["provider"] = provider }
            if let desc = enriched.details["description"]?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
               englishNoise.contains(desc) {
                enriched.details.removeValue(forKey: "description")
            }
            if let owner = enriched.details["owner"] {
                enriched.details["owner"] = normalizeNorwegianOwner(owner)
            }
            return enriched
        }
    }

    private nonisolated static func subtypeKey(forFile filename: String) -> String? {
        switch filename {
        case "swimming_spots": return "badeplass"
        case "giant_kettles": return "jettegryte"
        case "oxbow_lakes": return "kroksjo"
        case "lagoons": return "lagune"
        case "hot_springs": return "varme_kilder"
        default: return nil
        }
    }

    private nonisolated static func providerKey(forFile filename: String) -> String? {
        switch filename {
        case "dnt_hytter": return "dnt"
        case "andre_hytter": return "andre"
        default: return nil
        }
    }

    /// Normaliserer eier-/forvalter-strenger til norsk skrivemåte:
    /// felles substantiv som «turlag», «kommune», «kystlag» skal være med
    /// liten forbokstav når de står etter et stedsnavn (f.eks. «Bergen og
    /// Hordaland turlag», ikke «… Turlag»). Egennavn (Hotell, Fjellstue,
    /// AS-firmanavn osv.) lar vi være.
    private nonisolated static let lowercaseSuffixWords: Set<String> = [
        "Turlag", "Turforening", "Kommune", "Fylkeskommune",
        "Kystlag", "Sportsklubb", "Idrettsforening", "Speidergruppe",
        "Stedsgruppe", "Almenning", "Allmenning", "Frikirke", "Menighet",
    ]

    private nonisolated static func normalizeNorwegianOwner(_ name: String) -> String {
        let words = name.components(separatedBy: " ")
        guard words.count >= 2 else { return name }
        var result = words
        for i in 1..<result.count where lowercaseSuffixWords.contains(result[i]) {
            result[i] = result[i].lowercased()
        }
        return result.joined(separator: " ")
    }

    private nonisolated static func decodePOIs(from url: URL, category: POICategory) -> [POI] {
        guard let data = try? Data(contentsOf: url) else {
            Logger.poi.error("BundledPOI: could not read \(url.lastPathComponent, privacy: .public)")
            return []
        }

        let collection: BundledFeatureCollection
        do {
            collection = try JSONDecoder().decode(BundledFeatureCollection.self, from: data)
        } catch {
            Logger.poi.error("BundledPOI: failed to decode \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            return []
        }

        return collection.features.compactMap { feature -> POI? in
            guard feature.geometry.type == "Point",
                  feature.geometry.coordinates.count >= 2 else { return nil }

            let lon = feature.geometry.coordinates[0]
            let lat = feature.geometry.coordinates[1]
            guard lat.isFinite, lon.isFinite else { return nil }

            let name = feature.properties["name"] ?? category.displayName

            var details = feature.properties
            details.removeValue(forKey: "name")

            return POI(
                id: feature.id,
                category: category,
                name: name,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                details: details
            )
        }
    }
}

// MARK: - GeoJSON Decoding Types

private struct BundledFeatureCollection: Decodable {
    let features: [BundledFeature]
}

private struct BundledFeature: Decodable {
    let id: String
    let geometry: BundledGeometry
    let properties: [String: String]

    private enum CodingKeys: String, CodingKey {
        case id, geometry, properties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.geometry = try container.decode(BundledGeometry.self, forKey: .geometry)

        // GeoJSON-feltverdier kan være String, Int, Double, Bool eller null
        // avhengig av datakilde. Vi koerserer alt til String for uniform
        // POI.details — uten dette feilet hele feature-collection-decodingen
        // hvis bare ÉN feature hadde f.eks. `elevation: 235` (Int).
        let rawProps = try container.decode([String: JSONPropertyValue].self, forKey: .properties)
        self.properties = rawProps.mapValues(\.stringValue)
    }
}

private enum JSONPropertyValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else {
            self = .null
        }
    }

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d):
            // Vis hele tall uten desimal når mulig (12.0 → "12", 12.5 → "12.5")
            return d.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(d))
                : String(d)
        case .bool(let b): return String(b)
        case .null: return ""
        }
    }
}

private struct BundledGeometry: Decodable {
    let type: String
    let coordinates: [Double]
}
