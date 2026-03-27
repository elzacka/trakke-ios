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

// MARK: - Protocol

protocol WaterTemperatureFetching: Sendable {
    func getWaterTemperature(lat: Double, lon: Double) async throws -> WaterTemperatureResult
}

// MARK: - Service

actor WaterTemperatureService: WaterTemperatureFetching {
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
    private var cache: [String: CachedResult] = [:]

    private static let expiresFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()

    private func cacheKey(lat: Double, lon: Double) -> String {
        let truncLat = (lat * 100).rounded() / 100
        let truncLon = (lon * 100).rounded() / 100
        return "\(truncLat),\(truncLon)"
    }

    private static func parseExpires(from response: HTTPURLResponse) -> Date {
        if let expiresString = response.value(forHTTPHeaderField: "Expires"),
           let date = expiresFormatter.date(from: expiresString) {
            return date
        }
        return Date.now.addingTimeInterval(fallbackTTL)
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
        } catch {
            Logger.weather.warning("Ocean temperature fetch failed: \(error.localizedDescription, privacy: .private)")
            ocean = nil
        }

        let spots: [WaterTemperature]
        do {
            spots = try await bathingSpots
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
        guard let url = URL(string: "\(Self.oceanBaseURL)?lat=\(truncLat)&lon=\(truncLon)") else {
            return OceanFetchResult(temperature: nil, expiresAt: Date.now.addingTimeInterval(Self.fallbackTTL), lastModified: nil)
        }

        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        // Send If-Modified-Since if we have a cached Last-Modified (MET ToS requirement)
        let key = cacheKey(lat: lat, lon: lon)
        if let cached = cache[key], let lastModified = cached.lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await APIClient.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return OceanFetchResult(temperature: nil, expiresAt: Date.now.addingTimeInterval(Self.fallbackTTL), lastModified: nil)
        }

        let expiresAt = Self.parseExpires(from: httpResponse)
        let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")

        // 304 Not Modified: keep cached data, refresh expiry
        if httpResponse.statusCode == 304 {
            return OceanFetchResult(
                temperature: cache[key]?.result.oceanTemperature,
                expiresAt: expiresAt,
                lastModified: cache[key]?.lastModified
            )
        }

        guard httpResponse.statusCode == 200 else {
            return OceanFetchResult(temperature: nil, expiresAt: expiresAt, lastModified: lastModified)
        }

        return OceanFetchResult(
            temperature: parseOceanForecast(data),
            expiresAt: expiresAt,
            lastModified: lastModified
        )
    }

    private func parseOceanForecast(_ data: Data) -> WaterTemperature? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let properties = json["properties"] as? [String: Any],
              let timeseries = properties["timeseries"] as? [[String: Any]],
              !timeseries.isEmpty else {
            return nil
        }

        // Find the entry closest to now (formatter created once per call, actor-isolated)
        let now = Date.now
        let formatter = ISO8601DateFormatter()

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

    private func fetchBathingSpots(lat: Double, lon: Double) async throws -> [WaterTemperature] {
        let nearestParam = """
        {"points":[{"lat":\(lat),"lon":\(lon)}],"maxdist":30000,"maxcount":5}
        """

        guard let encoded = nearestParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(Self.bathingBaseURL)?nearest=\(encoded)") else {
            return []
        }

        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await APIClient.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        return parseBathingSpots(data)
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
