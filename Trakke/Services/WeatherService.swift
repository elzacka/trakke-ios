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

protocol WeatherFetching: Sendable {
    func getForecast(lat: Double, lon: Double) async throws -> WeatherForecast
    func clearCache() async
}

actor WeatherService: WeatherFetching {
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

    private static let expiresFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()

    private static func parseExpires(from response: HTTPURLResponse) -> Date {
        if let expiresString = response.value(forHTTPHeaderField: "Expires"),
           let date = expiresFormatter.date(from: expiresString) {
            return date
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

    // MARK: - Wind Chill (Følt temperatur)

    /// Environment Canada wind chill formula. Returns nil when wind chill is not
    /// meaningful (temperature > 10°C or wind < 4.8 km/h).
    nonisolated static func windChill(temperature: Double, windSpeedMs: Double) -> Double? {
        let windKmh = windSpeedMs * 3.6
        guard temperature <= 10, windKmh >= 4.8 else { return nil }
        let wc = 13.12 + 0.6215 * temperature
            - 11.37 * pow(windKmh, 0.16)
            + 0.3965 * temperature * pow(windKmh, 0.16)
        return wc
    }

    // MARK: - Precipitation Intensity

    /// Norwegian description of hourly precipitation amount.
    nonisolated static func precipitationDescription(_ mm: Double) -> String {
        switch mm {
        case ..<0.1: return String(localized: "weather.precip.none")
        case 0.1..<1.0: return String(localized: "weather.precip.light")
        case 1.0..<4.0: return String(localized: "weather.precip.moderate")
        default: return String(localized: "weather.precip.heavy")
        }
    }

    // MARK: - Precipitation Outdoor Impact

    /// Outdoor impact description for precipitation amount (mm/h).
    nonisolated static func precipitationOutdoorImpact(_ mm: Double) -> String {
        switch mm {
        case ..<0.1: return String(localized: "weather.precip.impact.none")
        case 0.1..<1.0: return String(localized: "weather.precip.impact.light")
        case 1.0..<4.0: return String(localized: "weather.precip.impact.moderate")
        default: return String(localized: "weather.precip.impact.heavy")
        }
    }

    // MARK: - Humidity Outdoor Impact

    /// Outdoor impact description for relative humidity.
    nonisolated static func humidityOutdoorImpact(_ humidity: Double) -> String {
        switch humidity {
        case ..<40: return String(localized: "weather.humidity.impact.low")
        case 40..<70: return String(localized: "weather.humidity.impact.moderate")
        case 70..<90: return String(localized: "weather.humidity.impact.high")
        default: return String(localized: "weather.humidity.impact.veryHigh")
        }
    }

    // MARK: - Temperature Outdoor Impact

    /// Outdoor safety description for temperature ranges.
    nonisolated static func temperatureOutdoorImpact(_ temp: Double, windChill: Double?) -> String {
        let effective = windChill ?? temp
        switch effective {
        case ..<(-20): return String(localized: "weather.temp.impact.extremeCold")
        case (-20)..<(-10): return String(localized: "weather.temp.impact.veryCold")
        case (-10)..<0: return String(localized: "weather.temp.impact.cold")
        case 0..<10: return String(localized: "weather.temp.impact.cool")
        case 10..<20: return String(localized: "weather.temp.impact.mild")
        default: return String(localized: "weather.temp.impact.warm")
        }
    }

    // MARK: - Wind Direction

    static let windDirections = ["N", "NO", "O", "SO", "S", "SV", "V", "NV"]

    nonisolated static func windDirectionName(_ degrees: Double) -> String {
        let index = ((Int((degrees / 45).rounded()) % 8) + 8) % 8
        return windDirections[index]
    }

    /// Unicode arrow showing the direction wind blows TOWARD (opposite of "from").
    nonisolated static func windDirectionArrow(_ degrees: Double) -> String {
        // Wind "from" north blows south, so rotate 180 degrees for "toward" arrow
        let toward = (degrees + 180).truncatingRemainder(dividingBy: 360)
        let arrows = ["\u{2191}", "\u{2197}", "\u{2192}", "\u{2198}", "\u{2193}", "\u{2199}", "\u{2190}", "\u{2196}"]
        let index = ((Int((toward / 45).rounded()) % 8) + 8) % 8
        return arrows[index]
    }

    /// Norwegian wind name based on Beaufort scale (Yr/MET standard).
    /// Uses exact Yr names, grouped for compact display where adjacent levels
    /// have similar outdoor impact.
    nonisolated static func windDescription(_ speed: Double) -> String {
        switch speed {
        case ..<0.3: return String(localized: "weather.wind.0")   // Stille
        case 0.3..<1.6: return String(localized: "weather.wind.1")  // Flau vind
        case 1.6..<3.4: return String(localized: "weather.wind.2")  // Svak vind
        case 3.4..<5.5: return String(localized: "weather.wind.3")  // Lett bris
        case 5.5..<8.0: return String(localized: "weather.wind.4")  // Laber bris
        case 8.0..<10.8: return String(localized: "weather.wind.5") // Frisk bris
        case 10.8..<13.9: return String(localized: "weather.wind.6") // Liten kuling
        case 13.9..<17.2: return String(localized: "weather.wind.7") // Stiv kuling
        case 17.2..<20.8: return String(localized: "weather.wind.8") // Sterk kuling
        case 20.8..<24.5: return String(localized: "weather.wind.9") // Liten storm
        case 24.5..<28.5: return String(localized: "weather.wind.10") // Full storm
        case 28.5..<32.7: return String(localized: "weather.wind.11") // Sterk storm
        default: return String(localized: "weather.wind.12")          // Orkan
        }
    }

    /// Beaufort level index for a given wind speed.
    nonisolated static func beaufortLevel(_ speed: Double) -> Int {
        switch speed {
        case ..<0.3: return 0
        case 0.3..<1.6: return 1
        case 1.6..<3.4: return 2
        case 3.4..<5.5: return 3
        case 5.5..<8.0: return 4
        case 8.0..<10.8: return 5
        case 10.8..<13.9: return 6
        case 13.9..<17.2: return 7
        case 17.2..<20.8: return 8
        case 20.8..<24.5: return 9
        case 24.5..<28.5: return 10
        case 28.5..<32.7: return 11
        default: return 12
        }
    }

    /// Land description for a Beaufort level (from Yr).
    nonisolated static func windLandDescription(_ speed: Double) -> String {
        let key = "weather.wind.land.\(beaufortLevel(speed))"
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Mountain description for a Beaufort level (from Yr).
    nonisolated static func windMountainDescription(_ speed: Double) -> String {
        let key = "weather.wind.mountain.\(beaufortLevel(speed))"
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Visual warning level for wind speed.
    nonisolated static func windWarningLevel(_ speed: Double) -> WindWarningLevel {
        switch speed {
        case ..<10.8: return .none       // Bft 0-5: safe
        case 10.8..<17.2: return .caution // Bft 6-7: be aware
        case 17.2..<32.7: return .danger  // Bft 8-11: dangerous outdoors
        default: return .extreme          // Bft 12: life-threatening
        }
    }

    enum WindWarningLevel {
        case none, caution, danger, extreme
    }

    // MARK: - Parsing

    private nonisolated(unsafe) static let iso8601Formatter = ISO8601DateFormatter()

    private func parseMetData(_ response: MetApiResponse, lat: Double, lon: Double) -> WeatherForecast {
        let timeseries = response.properties.timeseries
        let now = Date()
        let formatter = Self.iso8601Formatter

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
            let components = calendar.dateComponents([.year, .month, .day], from: item.date)
            let key = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
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
