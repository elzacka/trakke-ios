import Foundation
import CoreLocation

// MARK: - Elevation Point

struct ElevationPoint: Sendable {
    let coordinate: CLLocationCoordinate2D
    let elevation: Double
    let distance: Double // cumulative distance in meters
}

struct ElevationStats: Sendable {
    let gain: Int
    let loss: Int
    let min: Int
    let max: Int
    let average: Int
}

// MARK: - Elevation Service

actor ElevationService {
    private static let baseURL = "https://ws.geonorge.no/hoydedata/v1/punkt"
    private static let batchSize = 50
    private static let sampleInterval = 100.0 // meters
    private static let timeout: TimeInterval = 15

    func fetchElevationProfile(
        coordinates: [CLLocationCoordinate2D]
    ) async throws -> [ElevationPoint] {
        guard coordinates.count >= 2 else { return [] }

        let sampled = Haversine.sampleCoordinates(coordinates, interval: Self.sampleInterval)
        let elevations = try await fetchElevations(for: sampled)
        let distances = Haversine.cumulativeDistances(coordinates: sampled)

        return zip(zip(sampled, elevations), distances).map { pair, dist in
            ElevationPoint(
                coordinate: pair.0,
                elevation: pair.1,
                distance: dist
            )
        }
    }

    func calculateStats(from points: [ElevationPoint]) -> ElevationStats {
        guard !points.isEmpty else {
            return ElevationStats(gain: 0, loss: 0, min: 0, max: 0, average: 0)
        }

        var gain = 0.0
        var loss = 0.0
        var minElev = points[0].elevation
        var maxElev = points[0].elevation
        var totalElev = 0.0

        for point in points {
            minElev = min(minElev, point.elevation)
            maxElev = max(maxElev, point.elevation)
            totalElev += point.elevation
        }

        for i in 1..<points.count {
            let diff = points[i].elevation - points[i - 1].elevation
            if diff > 0 { gain += diff }
            else { loss += abs(diff) }
        }

        return ElevationStats(
            gain: Int(gain.rounded()),
            loss: Int(loss.rounded()),
            min: Int(minElev.rounded()),
            max: Int(maxElev.rounded()),
            average: Int((totalElev / Double(points.count)).rounded())
        )
    }

    func fetchElevation(coordinate: CLLocationCoordinate2D) async -> Double? {
        do {
            let elevations = try await fetchBatch([coordinate])
            return elevations.first
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private func fetchElevations(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
        var allElevations: [Double] = []

        for batchStart in stride(from: 0, to: coordinates.count, by: Self.batchSize) {
            let batchEnd = min(batchStart + Self.batchSize, coordinates.count)
            let batch = Array(coordinates[batchStart..<batchEnd])
            let elevations = try await fetchBatch(batch)
            allElevations.append(contentsOf: elevations)
        }

        return allElevations
    }

    private func fetchBatch(_ coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
        // Format as [[lon, lat], [lon, lat], ...]
        let punkter = coordinates.map { [Double]([($0.longitude * 1000000).rounded() / 1000000, ($0.latitude * 1000000).rounded() / 1000000]) }
        let punkterJSON = try JSONSerialization.data(withJSONObject: punkter)
        let punkterString = String(data: punkterJSON, encoding: .utf8) ?? "[]"

        guard var components = URLComponents(string: Self.baseURL) else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "koordsys", value: "4326"),
            URLQueryItem(name: "punkter", value: punkterString),
        ]

        guard let url = components.url else { throw APIError.invalidURL }

        let data = try await APIClient.fetchData(url: url, timeout: Self.timeout)
        let response = try JSONDecoder().decode(HoydedataResponse.self, from: data)

        return response.punkter.map(\.z)
    }
}

// MARK: - Response Type

private struct HoydedataResponse: Decodable {
    let punkter: [HoydedataPunkt]

    struct HoydedataPunkt: Decodable {
        let z: Double

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            z = (try? container.decode(Double.self, forKey: .z)) ?? 0
        }

        private enum CodingKeys: String, CodingKey {
            case z
        }
    }
}
