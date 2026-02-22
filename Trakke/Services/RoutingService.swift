import Foundation
import CoreLocation

// MARK: - Routing Error

enum RoutingError: Error, LocalizedError {
    case noRoute
    case offline
    case timeout
    case rateLimited
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .noRoute:
            return String(localized: "routing.error.noRoute")
        case .offline:
            return String(localized: "routing.error.offline")
        case .timeout:
            return String(localized: "routing.error.timeout")
        case .rateLimited:
            return String(localized: "routing.error.rateLimited")
        case .serverError(let code):
            return String(localized: "routing.error.server \(code)")
        case .decodingError:
            return String(localized: "routing.error.decoding")
        }
    }
}

// MARK: - Routing Service

/// Routes are computed via FOSSGIS's public Valhalla instance (valhalla1.openstreetmap.de).
/// This is a community-hosted service with no SLA or uptime guarantee. If the server is
/// unreachable, the UI falls back to compass-based navigation. Rate limiting is enforced
/// client-side via `minRequestInterval`. A self-hosted Valhalla instance would eliminate
/// this external dependency if needed in the future.
actor RoutingService {
    private static let baseURL = "https://valhalla1.openstreetmap.de/route"
    private static let timeout: TimeInterval = 30
    private static let minRequestInterval: TimeInterval = 1.5

    private var lastRequestTime: Date?
    private var cache: [String: ComputedRoute] = [:]
    private var cacheOrder: [String] = []

    // MARK: - Compute Route

    func computeRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> ComputedRoute {
        // Check cache
        let cacheKey = Self.cacheKey(from: origin, to: destination)
        if let cached = cache[cacheKey] {
            return cached
        }

        // Rate limiting (propagates CancellationError)
        try await enforceRateLimit()

        // Build request
        let requestBody = Self.buildRequestBody(from: origin, to: destination)

        guard let url = URL(string: Self.baseURL) else {
            throw RoutingError.noRoute
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(APIClient.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.timeout
        request.httpBody = requestBody

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await APIClient.session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw RoutingError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw RoutingError.offline
            case .cancelled:
                throw CancellationError()
            default:
                throw RoutingError.offline
            }
        } catch {
            throw RoutingError.offline
        }

        lastRequestTime = Date()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoutingError.noRoute
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw RoutingError.rateLimited
        case 400:
            throw RoutingError.noRoute
        default:
            throw RoutingError.serverError(httpResponse.statusCode)
        }

        let route = try Self.parseResponse(data)

        // Cache (limit to 20 entries, FIFO eviction)
        cache[cacheKey] = route
        cacheOrder.append(cacheKey)
        if cache.count > 20, let oldest = cacheOrder.first {
            cache.removeValue(forKey: oldest)
            cacheOrder.removeFirst()
        }

        return route
    }

    // MARK: - Clear Cache

    func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
    }

    // MARK: - Private

    private func enforceRateLimit() async throws {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < Self.minRequestInterval {
                let delay = Self.minRequestInterval - elapsed
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private static func cacheKey(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> String {
        // Round to 4 decimal places (~11m) for cache key stability
        let oLat = (origin.latitude * 10000).rounded() / 10000
        let oLon = (origin.longitude * 10000).rounded() / 10000
        let dLat = (destination.latitude * 10000).rounded() / 10000
        let dLon = (destination.longitude * 10000).rounded() / 10000
        return "\(oLat),\(oLon)->\(dLat),\(dLon)"
    }

    private static func buildRequestBody(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> Data? {
        let body: [String: Any] = [
            "locations": [
                ["lat": origin.latitude, "lon": origin.longitude],
                ["lat": destination.latitude, "lon": destination.longitude],
            ],
            "costing": "pedestrian",
            "costing_options": [
                "pedestrian": ["use_trails": 1.0],
            ],
            "directions_options": [
                "language": "nb-NO",
                "units": "km",
            ],
            "directions_type": "instructions",
        ]
        return try? JSONSerialization.data(withJSONObject: body)
    }

    private static func parseResponse(_ data: Data) throws -> ComputedRoute {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let trip = json["trip"] as? [String: Any],
              let legs = trip["legs"] as? [[String: Any]],
              let firstLeg = legs.first,
              let shape = firstLeg["shape"] as? String,
              let summary = trip["summary"] as? [String: Any] else {
            throw RoutingError.decodingError
        }

        let coordinates = Polyline6Decoder.decode(shape)
        guard !coordinates.isEmpty else { throw RoutingError.noRoute }

        // Parse summary
        let distance = (summary["length"] as? Double ?? 0) * 1000 // km -> meters
        let duration = summary["time"] as? Double ?? 0

        // Parse elevation from trip summary (Valhalla provides ascent/descent at trip level)
        let ascent = summary["ascent"] as? Double ?? 0
        let descent = summary["descent"] as? Double ?? 0

        // Parse maneuvers as turn instructions
        var instructions: [TurnInstruction] = []
        var cumulativeDistance = 0.0

        if let maneuvers = firstLeg["maneuvers"] as? [[String: Any]] {
            for maneuver in maneuvers {
                let text = maneuver["instruction"] as? String ?? ""
                let length = (maneuver["length"] as? Double ?? 0) * 1000
                let beginShapeIndex = maneuver["begin_shape_index"] as? Int ?? 0
                let typeValue = maneuver["type"] as? Int ?? 0

                let coordinate: CLLocationCoordinate2D
                if beginShapeIndex < coordinates.count {
                    coordinate = coordinates[beginShapeIndex]
                } else {
                    coordinate = coordinates.last ?? CLLocationCoordinate2D()
                }

                instructions.append(TurnInstruction(
                    text: text,
                    distance: cumulativeDistance,
                    coordinate: coordinate,
                    type: mapManeuverType(typeValue)
                ))

                cumulativeDistance += length
            }
        }

        // Route summary text
        let summaryText: String
        if let locations = trip["locations"] as? [[String: Any]] {
            let names = locations.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }
            summaryText = names.joined(separator: " - ")
        } else {
            summaryText = ""
        }

        return ComputedRoute(
            coordinates: coordinates,
            distance: distance,
            duration: duration,
            ascent: ascent,
            descent: descent,
            instructions: instructions,
            summary: summaryText
        )
    }

    /// Map Valhalla maneuver type integers to TurnType.
    private static func mapManeuverType(_ type: Int) -> TurnType {
        switch type {
        case 0: return .other       // None
        case 1: return .depart      // Start
        case 2: return .depart      // Start right
        case 3: return .depart      // Start left
        case 4: return .destination // Destination
        case 5: return .destination // Destination right
        case 6: return .destination // Destination left
        case 7: return .straight    // Becomes
        case 8: return .straight    // Continue
        case 9: return .slightRight
        case 10: return .right
        case 11: return .sharpRight
        case 12: return .uTurn
        case 13: return .uTurn
        case 14: return .sharpLeft
        case 15: return .left
        case 16: return .slightLeft
        case 17: return .straight   // Ramp straight
        case 18: return .slightRight // Ramp right
        case 19: return .slightLeft  // Ramp left
        case 24: return .straight    // Merge
        case 30: return .ferry       // Ferry enter
        case 31: return .ferry       // Ferry exit
        default: return .other
        }
    }
}
