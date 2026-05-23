import Foundation
import CoreLocation
import OSLog

// MARK: - Water Temperature Data

struct WaterTemperature: Sendable {
    let temperature: Double
    let source: Source
    let name: String?
    let fetchedAt: Date

    enum Source: Sendable {
        case oceanForecast      // MET Oceanforecast 2.0
        case bathingSpot        // Havvarsel-Frost badevann
    }
}

struct WaterTemperatureResult: Sendable {
    let oceanTemperature: WaterTemperature?
    let bathingSpots: [WaterTemperature]
    let coordinate: CLLocationCoordinate2D
    let fetchedAt: Date
}

// MARK: - Service

actor WaterTemperatureService {
    private static let oceanBaseURL = "https://api.met.no/weatherapi/oceanforecast/2.0/complete"
    private static let bathingBaseURL = "https://havvarsel-frost.met.no/api/v1/obs/badevann/get"
    private static let userAgent = APIClient.userAgent
    private static let timeout: TimeInterval = 15
    private static let fallbackTTL: TimeInterval = 3600 // 1 hour

    private struct CachedResult {
        let result: WaterTemperatureResult
        let expiresAt: Date
        let lastModified: String?
    }

    private static let maxCacheEntries = 10
    private let iso8601Formatter = ISO8601DateFormatter()
    private var cache: [String: CachedResult] = [:]
    private var bathingDisabledUntil: Date?

    func clearCache() {
        cache.removeAll()
        bathingDisabledUntil = nil
    }


    private func cacheKey(lat: Double, lon: Double) -> String {
        let truncLat = (lat * 10000).rounded() / 10000
        let truncLon = (lon * 10000).rounded() / 10000
        return "\(truncLat),\(truncLon)"
    }

    private static func parseExpires(from response: HTTPURLResponse) -> Date {
        HTTPDateParser.parseExpires(response, fallbackTTL: fallbackTTL)
    }

    func getWaterTemperature(lat: Double, lon: Double) async throws -> WaterTemperatureResult {
        let key = cacheKey(lat: lat, lon: lon)

        // Respect Expires header from previous response (MET ToS requirement)
        if let cached = cache[key], cached.expiresAt > Date.now {
            return cached.result
        }

        async let oceanTemp = fetchOceanTemperature(lat: lat, lon: lon)
        async let bathingSpots = fetchBathingSpots(lat: lat, lon: lon)

        let ocean: OceanFetchResult?
        do {
            ocean = try await oceanTemp
        } catch is CancellationError {
            // Task cancellation is expected when the user navigates away mid-fetch.
            // Not an error — don't log.
            ocean = nil
        } catch let urlError as URLError where urlError.code == .cancelled {
            ocean = nil
        } catch {
            Logger.weather.warning("Ocean temperature fetch failed: \(error.localizedDescription, privacy: .private)")
            ocean = nil
        }

        let spots: [WaterTemperature]
        do {
            spots = try await bathingSpots
        } catch is CancellationError {
            spots = []
        } catch let urlError as URLError where urlError.code == .cancelled {
            spots = []
        } catch {
            Logger.weather.warning("Bathing spots fetch failed: \(error.localizedDescription, privacy: .private)")
            spots = []
        }

        let result = WaterTemperatureResult(
            oceanTemperature: ocean?.temperature,
            bathingSpots: spots,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            fetchedAt: .now
        )

        // Cache the result with Expires from ocean response (or fallback TTL)
        if cache.count >= Self.maxCacheEntries {
            if let oldest = cache.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key {
                cache.removeValue(forKey: oldest)
            }
        }
        cache[key] = CachedResult(
            result: result,
            expiresAt: ocean?.expiresAt ?? Date.now.addingTimeInterval(Self.fallbackTTL),
            lastModified: ocean?.lastModified
        )

        return result
    }

    // MARK: - MET Oceanforecast

    private struct OceanFetchResult {
        let temperature: WaterTemperature?
        let expiresAt: Date
        let lastModified: String?
    }

    private func fetchOceanTemperature(lat: Double, lon: Double) async throws -> OceanFetchResult {
        let truncLat = (lat * 10000).rounded() / 10000
        let truncLon = (lon * 10000).rounded() / 10000

        var components = URLComponents(string: Self.oceanBaseURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(truncLat)),
            URLQueryItem(name: "lon", value: String(truncLon)),
        ]
        guard let url = components?.url else {
            return OceanFetchResult(temperature: nil, expiresAt: Date.now.addingTimeInterval(Self.fallbackTTL), lastModified: nil)
        }

        let key = cacheKey(lat: lat, lon: lon)
        let result: ConditionalFetchResult
        do {
            result = try await APIClient.fetchDataConditional(
                url: url,
                ifModifiedSince: cache[key]?.lastModified,
                timeout: Self.timeout
            )
        } catch {
            return OceanFetchResult(temperature: nil, expiresAt: Date.now.addingTimeInterval(Self.fallbackTTL), lastModified: nil)
        }

        let expiresAt = result.expires(fallbackTTL: Self.fallbackTTL)

        if result.notModified {
            return OceanFetchResult(
                temperature: cache[key]?.result.oceanTemperature,
                expiresAt: expiresAt,
                lastModified: cache[key]?.lastModified
            )
        }

        guard result.ok else {
            return OceanFetchResult(temperature: nil, expiresAt: expiresAt, lastModified: result.lastModified)
        }

        return OceanFetchResult(
            temperature: parseOceanForecast(result.data),
            expiresAt: expiresAt,
            lastModified: result.lastModified
        )
    }

    private func parseOceanForecast(_ data: Data) -> WaterTemperature? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let properties = json["properties"] as? [String: Any],
              let timeseries = properties["timeseries"] as? [[String: Any]],
              !timeseries.isEmpty else {
            return nil
        }

        let now = Date.now
        let formatter = iso8601Formatter

        var closestTemp: Double?
        var closestDistance: TimeInterval = .greatestFiniteMagnitude

        for entry in timeseries {
            guard let timeStr = entry["time"] as? String,
                  let time = formatter.date(from: timeStr),
                  let entryData = entry["data"] as? [String: Any],
                  let instant = entryData["instant"] as? [String: Any],
                  let details = instant["details"] as? [String: Any],
                  let temp = details["sea_water_temperature"] as? Double else {
                continue
            }

            let distance = abs(time.timeIntervalSince(now))
            if distance < closestDistance {
                closestDistance = distance
                closestTemp = temp
            }
        }

        guard let temperature = closestTemp else { return nil }

        return WaterTemperature(
            temperature: temperature,
            source: .oceanForecast,
            name: nil,
            fetchedAt: .now
        )
    }

    // MARK: - Havvarsel-Frost Badevann

    // Havvarsel-frost has shipped expired certificates before. Pause briefly on TLS
    // failure to avoid hammering the endpoint, but stay short enough that a recovered
    // cert (or transient network glitch) becomes visible in the next foreground.
    private static let bathingDisableInterval: TimeInterval = 30 * 60

    private func fetchBathingSpots(lat: Double, lon: Double) async throws -> [WaterTemperature] {
        if let until = bathingDisabledUntil, until > Date.now {
            return []
        }

        let truncLat = (lat * 10000).rounded() / 10000
        let truncLon = (lon * 10000).rounded() / 10000
        let nearestParam = """
        {"points":[{"lat":\(truncLat),"lon":\(truncLon)}],"maxdist":30000,"maxcount":5}
        """

        guard let encoded = nearestParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(Self.bathingBaseURL)?nearest=\(encoded)") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await APIClient.session.data(for: request)
        } catch let urlError as URLError where Self.isCertificateFailure(urlError) {
            bathingDisabledUntil = Date.now.addingTimeInterval(Self.bathingDisableInterval)
            Logger.weather.error("havvarsel-frost certificate failure (\(urlError.code.rawValue)) — disabling bathing-spot fetch until \(self.bathingDisabledUntil?.description ?? "?", privacy: .public)")
            return []
        }

        // TLS handshake succeeded — clear any prior backoff so the next failure
        // starts from a fresh window instead of stacking with stale state.
        bathingDisabledUntil = nil

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        return parseBathingSpots(data)
    }

    private static func isCertificateFailure(_ error: URLError) -> Bool {
        switch error.code {
        case .serverCertificateHasBadDate,
             .serverCertificateUntrusted,
             .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }

    private func parseBathingSpots(_ data: Data) -> [WaterTemperature] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            return []
        }

        var results: [WaterTemperature] = []

        for station in dataArray {
            guard let header = station["header"] as? [String: Any],
                  let name = header["name"] as? String,
                  let observations = station["observations"] as? [[String: Any]],
                  let latest = observations.last,
                  let body = latest["body"] as? [String: Any],
                  let temp = body["value"] as? Double else {
                continue
            }

            results.append(WaterTemperature(
                temperature: temp,
                source: .bathingSpot,
                name: name,
                fetchedAt: .now
            ))
        }

        return results
    }
}
