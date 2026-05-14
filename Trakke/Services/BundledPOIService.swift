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
            let allCategories: [POICategory] = [.caves, .viewpoints, .warMemorials, .wildernessShelters, .shelters, .swimmingSpot]
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
        // Badeplasser slås sammen til én kategori. To filer bidrar:
        // swimming_spots.geojson (uten strand) og swimming_spots_with_beach.geojson
        // (med strand). Variant-flagget settes per POI slik at kart-ikon og
        // detalj-badge kan skille dem, uten å bloate kategori-listen.
        if category == .swimmingSpot {
            let plain = loadFile(named: "swimming_spots", category: category, hasBeach: false)
            let beach = loadFile(named: "swimming_spots_with_beach", category: category, hasBeach: true)
            return plain + beach
        }

        let filenames: [POICategory: String] = [
            .caves: "caves",
            .viewpoints: "viewpoints",
            .warMemorials: "war_memorials",
            .wildernessShelters: "wilderness_shelters",
            .shelters: "shelters",
        ]
        guard let filename = filenames[category] else { return [] }
        return loadFile(named: filename, category: category, hasBeach: nil)
    }

    private nonisolated static func loadFile(named filename: String, category: POICategory, hasBeach: Bool?) -> [POI] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson", subdirectory: "POIData")
                ?? Bundle.main.url(forResource: filename, withExtension: "geojson") else {
            Logger.poi.error("BundledPOI: \(filename, privacy: .public).geojson not found in bundle")
            return []
        }
        return decodePOIs(from: url, category: category, hasBeach: hasBeach)
    }

    private nonisolated static func decodePOIs(from url: URL, category: POICategory, hasBeach: Bool?) -> [POI] {
        guard let data = try? Data(contentsOf: url) else { return [] }

        guard let collection = try? JSONDecoder().decode(BundledFeatureCollection.self, from: data) else {
            Logger.poi.error("BundledPOI: failed to decode \(url.lastPathComponent, privacy: .public)")
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
                details: details,
                hasBeach: hasBeach
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
}

private struct BundledGeometry: Decodable {
    let type: String
    let coordinates: [Double]
}
