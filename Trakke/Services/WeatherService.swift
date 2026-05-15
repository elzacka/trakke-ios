import Foundation
import CoreLocation

// MARK: - Weather Data

struct WeatherData: Sendable {
    let temperature: Double
    let temperatureMin: Double?
    let temperatureMax: Double?
    let overnightLow: Double?
    let overnightWindChill: Double?
    let precipitation: Double
    let precipitationProbability: Double
    let windSpeed: Double
    let windGust: Double?
    let windDirection: Double
    let humidity: Double
    let pressure: Double?
    let uvIndex: Double?
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

protocol WeatherFetching: Sendable {
    func getForecast(lat: Double, lon: Double) async throws -> WeatherForecast
    func clearCache() async
}

actor WeatherService: WeatherFetching {
    private static let baseURL = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
    private static let fallbackTTL: TimeInterval = 7200 // 2 hours, used when Expires header is missing
    private static let timeout: TimeInterval = 15

    private let decoder = JSONDecoder()

    private struct CachedForecast {
        let forecast: WeatherForecast
        let expiresAt: Date
        let lastModified: String?
    }

    private static let maxCacheEntries = 10

    private var cache: [String: CachedForecast] = [:]

    func clearCache() {
        cache.removeAll()
    }

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

        do {
            let result = try await APIClient.fetchDataConditional(
                url: url,
                ifModifiedSince: cache[cacheKey]?.lastModified,
                timeout: Self.timeout
            )

            if result.notModified, let cached = cache[cacheKey] {
                cache[cacheKey] = CachedForecast(
                    forecast: cached.forecast,
                    expiresAt: result.expires(fallbackTTL: Self.fallbackTTL),
                    lastModified: cached.lastModified
                )
                return cached.forecast
            }

            guard result.ok else {
                if let cached = cache[cacheKey] { return cached.forecast }
                throw APIError.httpError(statusCode: result.statusCode)
            }

            let metResponse = try decoder.decode(MetApiResponse.self, from: result.data)
            let forecast = parseMetData(metResponse, lat: truncLat, lon: truncLon)
            cache[cacheKey] = CachedForecast(
                forecast: forecast,
                expiresAt: result.expires(fallbackTTL: Self.fallbackTTL),
                lastModified: result.lastModified
            )
            evictStaleCacheEntries()
            return forecast
        } catch APIError.rateLimited {
            if let cached = cache[cacheKey] { return cached.forecast }
            throw APIError.rateLimited
        } catch let error as APIError {
            throw error
        } catch {
            if let cached = cache[cacheKey] { return cached.forecast }
            throw error
        }
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

    // MARK: - Advice (split into WeatherAdvice.swift)
    //
    // All `nonisolated static` advice + diagnostic helpers (windChill,
    // precipitationDescription, windWarningLevel, upcomingChange,
    // outdoorAssessment, …) live in WeatherAdvice.swift. They share this
    // namespace so call sites stay short.

    // MARK: - Parsing

    private let iso8601Formatter = ISO8601DateFormatter()

    private func parseMetData(_ response: MetApiResponse, lat: Double, lon: Double) -> WeatherForecast {
        let timeseries = response.properties.timeseries
        let now = Date()
        let formatter = iso8601Formatter

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
                overnightLow: nil,
                overnightWindChill: nil,
                precipitation: precip,
                precipitationProbability: precipProb,
                windSpeed: instant.wind_speed,
                windGust: instant.wind_speed_of_gust,
                windDirection: instant.wind_from_direction,
                humidity: instant.relative_humidity,
                pressure: instant.air_pressure_at_sea_level,
                uvIndex: instant.ultraviolet_index_clear_sky,
                cloudCoverage: instant.cloud_area_fraction ?? 0,
                symbol: symbol,
                time: date
            )
            return (date, wd)
        }

        // Current: closest to now
        let current = parsed.min(by: { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) })?.data
            ?? WeatherData(temperature: 0, temperatureMin: nil, temperatureMax: nil,
                          overnightLow: nil, overnightWindChill: nil,
                          precipitation: 0, precipitationProbability: 0,
                          windSpeed: 0, windGust: nil, windDirection: 0,
                          humidity: 0, pressure: nil, uvIndex: nil, cloudCoverage: 0,
                          symbol: "cloudy", time: now)

        // Hourly: next 24 hours
        let hourly = parsed.filter { $0.date > now && $0.date < now.addingTimeInterval(86400) }
            .map(\.data)

        // Daily: group by calendar day, pick noon
        let calendar = Calendar.current
        var dailyMap: [String: [(date: Date, data: WeatherData)]] = [:]
        for item in parsed where item.date > now {
            let components = calendar.dateComponents([.year, .month, .day], from: item.date)
            guard let year = components.year, let month = components.month, let day = components.day else { continue }
            let key = String(format: "%04d-%02d-%02d", year, month, day)
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

            // Use the strongest gust across the entire day (worst-case for safety)
            let maxGust = points.compactMap(\.data.windGust).max()
            let maxUV = points.compactMap(\.data.uvIndex).max()

            // Overnight low: night hours (20:00-06:00) for camping safety
            let nightPoints = points.filter {
                let hour = calendar.component(.hour, from: $0.date)
                return hour >= 20 || hour <= 6
            }
            let overnightLow = nightPoints.map(\.data.temperature).min()
            let overnightWindChill: Double? = nightPoints.min(by: { $0.data.temperature < $1.data.temperature }).flatMap {
                Self.windChill(temperature: $0.data.temperature, windSpeedMs: $0.data.windSpeed)
            }

            return WeatherData(
                temperature: noon.temperature,
                temperatureMin: minTemp,
                temperatureMax: maxTemp,
                overnightLow: overnightLow,
                overnightWindChill: overnightWindChill,
                precipitation: noon.precipitation,
                precipitationProbability: noon.precipitationProbability,
                windSpeed: noon.windSpeed,
                windGust: maxGust,
                windDirection: noon.windDirection,
                humidity: noon.humidity,
                pressure: noon.pressure,
                uvIndex: maxUV,
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
        let wind_speed_of_gust: Double?
        let wind_from_direction: Double
        let relative_humidity: Double
        let air_pressure_at_sea_level: Double?
        let ultraviolet_index_clear_sky: Double?
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
