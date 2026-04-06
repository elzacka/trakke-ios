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

// MARK: - Protocol

protocol ElevationFetching: Sendable {
    func fetchElevationProfile(coordinates: [CLLocationCoordinate2D]) async throws -> [ElevationPoint]
    nonisolated func calculateStats(from points: [ElevationPoint]) -> ElevationStats
    func fetchElevation(coordinate: CLLocationCoordinate2D) async -> Double?
    func clearCache() async
}

// MARK: - Elevation Service

actor ElevationService: ElevationFetching {
    private static let baseURL = "https://ws.geonorge.no/hoydedata/v1/punkt"
    private static let batchSize = 50
    private static let sampleInterval = 100.0 // meters
    private static let timeout: TimeInterval = 15

    // MARK: - Profile cache (elevation data is static; no TTL needed)

    private var profileCache: [String: [ElevationPoint]] = [:]
    private var profileCacheOrder: [String] = []
    private static let profileCacheLimit = 5

    private func profileCacheKey(for coordinates: [CLLocationCoordinate2D]) -> String {
        guard let first = coordinates.first, let last = coordinates.last else { return "" }
        let count = coordinates.count
        // Round to 4 decimal places (~11m) so near-identical requests hit the cache
        let f = "\((first.latitude * 10000).rounded() / 10000),\((first.longitude * 10000).rounded() / 10000)"
        let l = "\((last.latitude * 10000).rounded() / 10000),\((last.longitude * 10000).rounded() / 10000)"
        return "\(f)|\(l)|\(count)"
    }

    func clearCache() {
        profileCache.removeAll()
        profileCacheOrder.removeAll()
    }

    private func cacheProfile(_ points: [ElevationPoint], forKey key: String) {
        profileCache[key] = points
        profileCacheOrder.append(key)
        if profileCache.count > Self.profileCacheLimit, let oldest = profileCacheOrder.first {
            profileCache.removeValue(forKey: oldest)
            profileCacheOrder.removeFirst()
        }
    }

    func fetchElevationProfile(
        coordinates: [CLLocationCoordinate2D]
    ) async throws -> [ElevationPoint] {
        let validCoordinates = coordinates.filter { $0.latitude.isFinite && $0.longitude.isFinite }
        guard validCoordinates.count >= 2 else { return [] }

        let cacheKey = profileCacheKey(for: validCoordinates)
        if let cached = profileCache[cacheKey] {
            return cached
        }

        let sampled = Haversine.sampleCoordinates(validCoordinates, interval: Self.sampleInterval)
        let elevations = try await fetchElevations(for: sampled)
        let distances = Haversine.cumulativeDistances(coordinates: sampled)

        // Filter out points where the elevation lookup returned nil (e.g. sea/outside coverage)
        let points = zip(zip(sampled, elevations), distances).compactMap { pair, dist -> ElevationPoint? in
            guard let elevation = pair.1 else { return nil }
            return ElevationPoint(
                coordinate: pair.0,
                elevation: elevation,
                distance: dist
            )
        }

        cacheProfile(points, forKey: cacheKey)
        return points
    }

    nonisolated func calculateStats(from points: [ElevationPoint]) -> ElevationStats {
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
            return elevations.first ?? nil
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private static let maxConcurrentBatches = 4

    private func fetchElevations(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double?] {
        // Split into batches
        var batches: [(index: Int, coords: [CLLocationCoordinate2D])] = []
        for (i, batchStart) in stride(from: 0, to: coordinates.count, by: Self.batchSize).enumerated() {
            let batchEnd = min(batchStart + Self.batchSize, coordinates.count)
            batches.append((i, Array(coordinates[batchStart..<batchEnd])))
        }

        // Fetch batches concurrently with a concurrency limit
        var results: [(index: Int, elevations: [Double?])] = []

        try await withThrowingTaskGroup(of: (Int, [Double?]).self) { group in
            var submitted = 0

            for batch in batches {
                if submitted >= Self.maxConcurrentBatches {
                    if let result = try await group.next() {
                        results.append((index: result.0, elevations: result.1))
                    }
                }
                group.addTask {
                    let elevations = try await self.fetchBatch(batch.coords)
                    return (batch.index, elevations)
                }
                submitted += 1
            }

            for try await result in group {
                results.append((index: result.0, elevations: result.1))
            }
        }

        // Reassemble in original order
        return results.sorted { $0.index < $1.index }.flatMap(\.elevations)
    }

    private func fetchBatch(_ coordinates: [CLLocationCoordinate2D]) async throws -> [Double?] {
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
        // nil when the point falls outside coverage (e.g. sea, outside Norway)
        let z: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            z = try? container.decode(Double.self, forKey: .z)
        }

        private enum CodingKeys: String, CodingKey {
            case z
        }
    }
}
