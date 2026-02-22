import Foundation
import CoreLocation

// MARK: - Weather Data

struct WeatherData: Sendable {
    let temperature: Double
    let temperatureMin: Double?
    let temperatureMax: Double?
    let precipitation: Double
    let precipitationProbability: Double
    let windSpeed: Double
    let windDirection: Double
    let humidity: Double
    let cloudCoverage: Double
    let symbol: String
    let time: Date
}

struct WeatherForecast: Sendable {
    let location: CLLocationCoordinate2D
    let current: WeatherData
    let hourly: [WeatherData]
    let daily: [WeatherData]
    let fetchedAt: Date
}

// MARK: - Weather Service

actor WeatherService {
    private static let baseURL = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
    private static let userAgent = APIClient.userAgent
    private static let fallbackTTL: TimeInterval = 7200 // 2 hours, used when Expires header is missing
    private static let timeout: TimeInterval = 15

    private struct CachedForecast {
        let forecast: WeatherForecast
        let expiresAt: Date
        let lastModified: String?
    }

    private static let maxCacheEntries = 10

    private var cache: [String: CachedForecast] = [:]

    func getForecast(lat: Double, lon: Double) async throws -> WeatherForecast {
        let truncLat = (lat * 10000).rounded() / 10000
        let truncLon = (lon * 10000).rounded() / 10000
        let cacheKey = "\(truncLat),\(truncLon)"

        // Respect Expires header from previous response (MET ToS requirement)
        if let cached = cache[cacheKey], cached.expiresAt > Date() {
            return cached.forecast
        }

        guard var components = URLComponents(string: Self.baseURL) else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(truncLat)),
            URLQueryItem(name: "lon", value: String(truncLon)),
        ]

        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.timeout

        // Send If-Modified-Since if we have a cached Last-Modified (MET ToS requirement)
        if let cached = cache[cacheKey], let lastModified = cached.lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        do {
            let (data, response) = try await APIClient.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 304 {
                // Not modified: refresh expiry from new Expires header, keep cached data
                if let cached = cache[cacheKey] {
                    let expires = Self.parseExpires(from: httpResponse)
                    cache[cacheKey] = CachedForecast(
                        forecast: cached.forecast,
                        expiresAt: expires,
                        lastModified: cached.lastModified
                    )
                    return cached.forecast
                }
            }

            if httpResponse.statusCode == 429 {
                if let cached = cache[cacheKey] { return cached.forecast }
                throw APIError.rateLimited
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                if let cached = cache[cacheKey] { return cached.forecast }
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let metResponse = try JSONDecoder().decode(MetApiResponse.self, from: data)
            let forecast = parseMetData(metResponse, lat: truncLat, lon: truncLon)

            let expires = Self.parseExpires(from: httpResponse)
            let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
            cache[cacheKey] = CachedForecast(
                forecast: forecast,
                expiresAt: expires,
                lastModified: lastModified
            )
            evictStaleCacheEntries()
            return forecast
        } catch let error as APIError {
            throw error
        } catch {
            if let cached = cache[cacheKey] { return cached.forecast }
            throw error
        }
    }

    private static func parseExpires(from response: HTTPURLResponse) -> Date {
        if let expiresString = response.value(forHTTPHeaderField: "Expires") {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "GMT")
            if let date = formatter.date(from: expiresString) {
                return date
            }
        }
        return Date().addingTimeInterval(fallbackTTL)
    }

    private func evictStaleCacheEntries() {
        let now = Date()
        cache = cache.filter { $0.value.expiresAt > now }
        if cache.count > Self.maxCacheEntries {
            let sorted = cache.sorted { $0.value.expiresAt < $1.value.expiresAt }
            let toRemove = cache.count - Self.maxCacheEntries
            for entry in sorted.prefix(toRemove) {
                cache.removeValue(forKey: entry.key)
            }
        }
    }

    // MARK: - Wind Direction

    static let windDirections = ["N", "NO", "O", "SO", "S", "SV", "V", "NV"]

    nonisolated static func windDirectionName(_ degrees: Double) -> String {
        let index = ((Int((degrees / 45).rounded()) % 8) + 8) % 8
        return windDirections[index]
    }

    // MARK: - Parsing

    private func parseMetData(_ response: MetApiResponse, lat: Double, lon: Double) -> WeatherForecast {
        let timeseries = response.properties.timeseries
        let now = Date()
        let formatter = ISO8601DateFormatter()

        let parsed: [(date: Date, data: WeatherData)] = timeseries.compactMap { point in
            guard let date = formatter.date(from: point.time) else { return nil }
            let instant = point.data.instant.details
            let next1h = point.data.next_1_hours
            let next6h = point.data.next_6_hours

            let symbol = next1h?.summary.symbol_code ?? next6h?.summary.symbol_code ?? "cloudy"
            let precip = next1h?.details?.precipitation_amount ?? next6h?.details?.precipitation_amount ?? 0
            let precipProb = next1h?.details?.precipitation_probability ?? next6h?.details?.precipitation_probability ?? 0

            let wd = WeatherData(
                temperature: instant.air_temperature,
                temperatureMin: nil,
                temperatureMax: nil,
                precipitation: precip,
                precipitationProbability: precipProb,
                windSpeed: instant.wind_speed,
                windDirection: instant.wind_from_direction,
                humidity: instant.relative_humidity,
                cloudCoverage: instant.cloud_area_fraction ?? 0,
                symbol: symbol,
                time: date
            )
            return (date, wd)
        }

        // Current: closest to now
        let current = parsed.min(by: { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) })?.data
            ?? WeatherData(temperature: 0, temperatureMin: nil, temperatureMax: nil,
                          precipitation: 0, precipitationProbability: 0,
                          windSpeed: 0, windDirection: 0, humidity: 0, cloudCoverage: 0,
                          symbol: "cloudy", time: now)

        // Hourly: next 24 hours
        let hourly = parsed.filter { $0.date > now && $0.date < now.addingTimeInterval(86400) }
            .map(\.data)

        // Daily: group by calendar day, pick noon
        let calendar = Calendar.current
        var dailyMap: [String: [(date: Date, data: WeatherData)]] = [:]
        for item in parsed where item.date > now {
            let key = calendar.startOfDay(for: item.date).description
            dailyMap[key, default: []].append(item)
        }

        let daily = dailyMap.sorted { $0.key < $1.key }.prefix(7).compactMap { _, points -> WeatherData? in
            // Pick point closest to noon for representative data
            guard let noon = points.min(by: {
                let h0 = calendar.component(.hour, from: $0.date)
                let h1 = calendar.component(.hour, from: $1.date)
                return abs(h0 - 12) < abs(h1 - 12)
            })?.data else { return nil }

            // Compute min/max from all data points in this day
            let temps = points.map(\.data.temperature)
            let minTemp = temps.min()
            let maxTemp = temps.max()

            return WeatherData(
                temperature: noon.temperature,
                temperatureMin: minTemp,
                temperatureMax: maxTemp,
                precipitation: noon.precipitation,
                precipitationProbability: noon.precipitationProbability,
                windSpeed: noon.windSpeed,
                windDirection: noon.windDirection,
                humidity: noon.humidity,
                cloudCoverage: noon.cloudCoverage,
                symbol: noon.symbol,
                time: noon.time
            )
        }

        return WeatherForecast(
            location: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            current: current,
            hourly: Array(hourly),
            daily: Array(daily),
            fetchedAt: now
        )
    }
}

// MARK: - MET API Response

private struct MetApiResponse: Decodable {
    let properties: MetProperties

    struct MetProperties: Decodable {
        let timeseries: [MetTimepoint]
    }

    struct MetTimepoint: Decodable {
        let time: String
        let data: MetData
    }

    struct MetData: Decodable {
        let instant: MetInstant
        let next_1_hours: MetPeriod?
        let next_6_hours: MetPeriod?
    }

    struct MetInstant: Decodable {
        let details: MetDetails
    }

    struct MetDetails: Decodable {
        let air_temperature: Double
        let wind_speed: Double
        let wind_from_direction: Double
        let relative_humidity: Double
        let cloud_area_fraction: Double?
    }

    struct MetPeriod: Decodable {
        let summary: MetSummary
        let details: MetPeriodDetails?
    }

    struct MetSummary: Decodable {
        let symbol_code: String
    }

    struct MetPeriodDetails: Decodable {
        let precipitation_amount: Double?
        let precipitation_probability: Double?
    }
}
