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
            let allCategories: [POICategory] = [.caves, .viewpoints, .warMemorials, .wildernessShelters]
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
        let filenames: [POICategory: String] = [
            .caves: "caves",
            .viewpoints: "viewpoints",
            .warMemorials: "war_memorials",
            .wildernessShelters: "wilderness_shelters",
        ]
        guard let filename = filenames[category] else { return [] }

        guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson", subdirectory: "POIData") else {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson") else {
                Logger.poi.error("BundledPOI: \(filename, privacy: .public).geojson not found in bundle")
                return []
            }
            return decodePOIs(from: url, category: category)
        }

        return decodePOIs(from: url, category: category)
    }

    private nonisolated static func decodePOIs(from url: URL, category: POICategory) -> [POI] {
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
}

private struct BundledGeometry: Decodable {
    let type: String
    let coordinates: [Double]
}
