import Foundation
import CoreLocation

// MARK: - Kommune Region

struct KommuneRegion: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let fylke: String
    let fylkenummer: String
    let south: Double
    let west: Double
    let north: Double
    let east: Double

    func estimatedTileCount(minZoom: Int, maxZoom: Int) -> Int {
        OfflineMapService.estimateTileCount(
            south: south, west: west, north: north, east: east,
            minZoom: minZoom, maxZoom: maxZoom
        )
    }

    /// Finds the highest maxZoom (capped at 15) where tile count stays under the limit.
    /// 50,000 tiles ensures all kommuner reach at least z14 — the minimum for confident
    /// trail navigation (shelters, junctions, and all marked trails clearly visible).
    func optimalMaxZoom(minZoom: Int = 8, tileLimit: Int = 50_000, maxCap: Int = 15) -> Int {
        for zoom in stride(from: maxCap, through: minZoom, by: -1) {
            if estimatedTileCount(minZoom: minZoom, maxZoom: zoom) <= tileLimit {
                return zoom
            }
        }
        return minZoom
    }

    var areaDimensions: String {
        let sw = CLLocationCoordinate2D(latitude: south, longitude: west)
        let se = CLLocationCoordinate2D(latitude: south, longitude: east)
        let nw = CLLocationCoordinate2D(latitude: north, longitude: west)
        let widthKm = Haversine.distance(from: sw, to: se) / 1000
        let heightKm = Haversine.distance(from: sw, to: nw) / 1000
        return String(format: "ca. %.0f \u{00d7} %.0f km", widthKm, heightKm)
    }
}

// MARK: - File Wrapper

struct KommuneFile: Codable, Sendable {
    let version: Int
    let kommuner: [KommuneRegion]
}
