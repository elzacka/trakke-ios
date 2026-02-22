import Foundation
import CoreLocation

// MARK: - Bundled POI Service

/// Loads pre-bundled GeoJSON POI data from the app bundle and filters by viewport.
/// Used for static OSM data (caves, observation towers, war memorials, wilderness shelters)
/// that rarely changes and doesn't need live API fetching.
@MainActor
enum BundledPOIService {
    private static var cache: [POICategory: [POI]] = [:]

    static func pois(for category: POICategory, in bounds: ViewportBounds) -> [POI] {
        let all = loadIfNeeded(category)
        return all.filter { bounds.contains($0.coordinate) }
    }

    static func clearCache() {
        cache.removeAll()
    }

    // MARK: - Loading

    private static func loadIfNeeded(_ category: POICategory) -> [POI] {
        if let cached = cache[category] { return cached }
        let pois = loadFromBundle(category)
        cache[category] = pois
        #if DEBUG
        print("BundledPOI: loaded \(pois.count) \(category.rawValue) from bundle")
        #endif
        return pois
    }

    private static let filenames: [POICategory: String] = [
        .caves: "caves",
        .viewpoints: "viewpoints",
        .warMemorials: "war_memorials",
        .wildernessShelters: "wilderness_shelters",
    ]

    private static func loadFromBundle(_ category: POICategory) -> [POI] {
        guard let filename = filenames[category] else { return [] }

        guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson", subdirectory: "POIData") else {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson") else {
                #if DEBUG
                print("BundledPOI: \(filename).geojson not found in bundle")
                #endif
                return []
            }
            return decodePOIs(from: url, category: category)
        }

        return decodePOIs(from: url, category: category)
    }

    private nonisolated static func decodePOIs(from url: URL, category: POICategory) -> [POI] {
        guard let data = try? Data(contentsOf: url) else { return [] }

        guard let collection = try? JSONDecoder().decode(BundledFeatureCollection.self, from: data) else {
            #if DEBUG
            print("BundledPOI: failed to decode \(url.lastPathComponent)")
            #endif
            return []
        }

        return collection.features.compactMap { feature -> POI? in
            guard feature.geometry.type == "Point",
                  feature.geometry.coordinates.count >= 2 else { return nil }

            let lon = feature.geometry.coordinates[0]
            let lat = feature.geometry.coordinates[1]

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
