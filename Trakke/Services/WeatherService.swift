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

    /// Concrete sensory description of what a precipitation amount looks/feels like.
    /// Thresholds: < 1 mm/h is drizzle range per SNL (yr = up to 1 mm/h in heavy
    /// drizzle). > 20 mm/h is MET yellow warning level for intense rain (SNL/skybrudd).
    /// Mid-range (1-20 mm/h) has no official Norwegian classification, so descriptions
    /// are based on general outdoor experience.
    nonisolated static func precipitationFeelsLike(_ mm: Double) -> String {
        switch mm {
        case ..<0.1: return String(localized: "weather.precip.feels.none")
        case 0.1..<1.0: return String(localized: "weather.precip.feels.drizzle")
        case 1.0..<5.0: return String(localized: "weather.precip.feels.moderate")
        case 5.0..<20.0: return String(localized: "weather.precip.feels.heavy")
        default: return String(localized: "weather.precip.feels.torrential")
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

    static let windDirections = ["N", "NØ", "Ø", "SØ", "S", "SV", "V", "NV"]
    static let windDirectionsFull = ["nord", "nordøst", "øst", "sørøst", "sør", "sørvest", "vest", "nordvest"]

    nonisolated static func windDirectionName(_ degrees: Double) -> String {
        let index = ((Int((degrees / 45).rounded()) % 8) + 8) % 8
        return windDirections[index]
    }

    /// Full Norwegian name for wind direction (e.g., "sørøst"). For use in tooltips.
    nonisolated static func windDirectionFullName(_ degrees: Double) -> String {
        let index = ((Int((degrees / 45).rounded()) % 8) + 8) % 8
        return windDirectionsFull[index]
    }

    /// Explains why the wind direction matters for weather and trip planning.
    /// Wind direction determines what type of air masses arrive — wet oceanic air
    /// from the west vs. cold continental air from the east, etc.
    /// Source: MET/Yr general meteorology, verified against SNL (vindretning).
    nonisolated static func windDirectionContext(_ degrees: Double) -> String {
        let index = ((Int((degrees / 45).rounded()) % 8) + 8) % 8
        return switch index {
        case 0: // N
            String(localized: "weather.wind.context.north")
        case 1: // NE
            String(localized: "weather.wind.context.northeast")
        case 2: // E
            String(localized: "weather.wind.context.east")
        case 3: // SE
            String(localized: "weather.wind.context.southeast")
        case 4: // S
            String(localized: "weather.wind.context.south")
        case 5: // SW
            String(localized: "weather.wind.context.southwest")
        case 6: // W
            String(localized: "weather.wind.context.west")
        case 7: // NW
            String(localized: "weather.wind.context.northwest")
        default:
            ""
        }
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
        case 0.3..<1.6: return String(localized: "weather.wind.1")  // Nesten stille
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

    enum WindWarningLevel: Int, Comparable {
        case none = 0, caution = 1, danger = 2, extreme = 3

        static func < (lhs: WindWarningLevel, rhs: WindWarningLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Warning level based on gust speed (m/s). Uses the same thresholds as
    /// sustained wind, but gusts at these speeds are more dangerous because
    /// they hit without warning.
    nonisolated static func gustWarningLevel(_ gustSpeed: Double) -> WindWarningLevel {
        switch gustSpeed {
        case ..<10.8: return .none
        case 10.8..<17.2: return .caution
        case 17.2..<32.7: return .danger
        default: return .extreme
        }
    }

    // MARK: - Pressure Trend

    enum PressureTrend: String {
        case rising, falling, stable
    }

    /// Full pressure analysis with trend and supporting evidence.
    struct PressureInfo: Sendable {
        let trend: PressureTrend
        let currentHPa: Double
        let earlierHPa: Double
        let changeHPa: Double
    }

    /// Determine pressure trend from hourly data. Compares current pressure
    /// to the value 3 hours ago. A change > 1 hPa is significant.
    nonisolated static func pressureTrend(current: Double?, hourly: [WeatherData]) -> PressureTrend? {
        pressureInfo(current: current, hourly: hourly)?.trend
    }

    /// Full pressure analysis including the raw change for verifiable display.
    nonisolated static func pressureInfo(current: Double?, hourly: [WeatherData]) -> PressureInfo? {
        guard let current else { return nil }
        let threeHoursAgo = Date().addingTimeInterval(-10800)
        guard let earlier = hourly.min(by: {
            abs($0.time.timeIntervalSince(threeHoursAgo)) < abs($1.time.timeIntervalSince(threeHoursAgo))
        }), let earlierPressure = earlier.pressure else { return nil }
        let diff = current - earlierPressure
        let trend: PressureTrend
        if diff > 1 { trend = .rising }
        else if diff < -1 { trend = .falling }
        else { trend = .stable }
        return PressureInfo(
            trend: trend,
            currentHPa: current,
            earlierHPa: earlierPressure,
            changeHPa: diff
        )
    }

    // MARK: - Pressure Outdoor Impact

    nonisolated static func pressureOutdoorImpact(_ trend: PressureTrend) -> String {
        switch trend {
        case .rising: return String(localized: "weather.pressure.impact.rising")
        case .falling: return String(localized: "weather.pressure.impact.falling")
        case .stable: return String(localized: "weather.pressure.impact.stable")
        }
    }

    // MARK: - UV Index (WHO/SNL scale)

    enum UVLevel: Int {
        case low = 0        // 0-2
        case moderate = 1   // 3-5
        case high = 2       // 6-7
        case veryHigh = 3   // 8-10
        case extreme = 4    // 11+
    }

    nonisolated static func uvLevel(_ index: Double) -> UVLevel {
        switch index {
        case ..<3: return .low
        case 3..<6: return .moderate
        case 6..<8: return .high
        case 8..<11: return .veryHigh
        default: return .extreme
        }
    }

    nonisolated static func uvDescription(_ index: Double) -> String {
        switch uvLevel(index) {
        case .low: return String(localized: "weather.uv.low")
        case .moderate: return String(localized: "weather.uv.moderate")
        case .high: return String(localized: "weather.uv.high")
        case .veryHigh: return String(localized: "weather.uv.veryHigh")
        case .extreme: return String(localized: "weather.uv.extreme")
        }
    }

    nonisolated static func uvOutdoorImpact(_ index: Double) -> String {
        switch uvLevel(index) {
        case .low: return String(localized: "weather.uv.impact.low")
        case .moderate: return String(localized: "weather.uv.impact.moderate")
        case .high: return String(localized: "weather.uv.impact.high")
        case .veryHigh: return String(localized: "weather.uv.impact.veryHigh")
        case .extreme: return String(localized: "weather.uv.impact.extreme")
        }
    }

    // MARK: - Upcoming Weather Change

    struct UpcomingChange: Sendable {
        let description: String
        let hour: String
        let severity: WindWarningLevel
    }

    /// Precipitation type derived from MET weather symbol.
    enum PrecipitationType {
        case rain, snow, sleet
    }

    /// Determines precipitation type from a MET symbol code.
    /// Snow and sleet require different clothing and preparation than rain.
    nonisolated static func precipitationType(for symbol: String) -> PrecipitationType {
        let base = symbol.lowercased()
        if base.contains("snow") { return .snow }
        if base.contains("sleet") { return .sleet }
        return .rain
    }

    /// Scans the next 6 hours for significant weather transitions:
    /// precipitation starting, wind picking up, or gusts becoming dangerous.
    /// Returns the most important upcoming change, or nil if conditions are stable.
    nonisolated static func upcomingChange(current: WeatherData, hourly: [WeatherData]) -> UpcomingChange? {
        let now = Date()
        let sixHoursLater = now.addingTimeInterval(21600)
        let upcoming = hourly.filter { $0.time > now && $0.time <= sixHoursLater }
        guard !upcoming.isEmpty else { return nil }

        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "HH"

        // Check for precipitation starting (currently dry → precipitation within 6h)
        if current.precipitation < 0.1 {
            if let precipStart = upcoming.first(where: { $0.precipitationProbability > 50 && $0.precipitation > 0.5 }) {
                let hour = hourFormatter.string(from: precipStart.time)
                let severity: WindWarningLevel = precipStart.precipitation > 4 ? .caution : .none
                let key: String.LocalizationValue = switch precipitationType(for: precipStart.symbol) {
                case .snow: "weather.upcoming.snow \(hour)"
                case .sleet: "weather.upcoming.sleet \(hour)"
                case .rain: "weather.upcoming.rain \(hour)"
                }
                return UpcomingChange(
                    description: String(localized: key),
                    hour: hour,
                    severity: severity
                )
            }
        }

        // Check for wind increasing significantly (gusts becoming dangerous)
        let currentWorstWind = max(
            windWarningLevel(current.windSpeed),
            gustWarningLevel(current.windGust ?? current.windSpeed)
        )
        for point in upcoming {
            let futureWorstWind = max(
                windWarningLevel(point.windSpeed),
                gustWarningLevel(point.windGust ?? point.windSpeed)
            )
            if futureWorstWind > currentWorstWind && futureWorstWind >= .caution {
                let hour = hourFormatter.string(from: point.time)
                return UpcomingChange(
                    description: String(localized: "weather.upcoming.wind \(hour)"),
                    hour: hour,
                    severity: futureWorstWind
                )
            }
        }

        // Check for heavy precipitation increase
        if current.precipitation < 1 {
            if let heavyStart = upcoming.first(where: { $0.precipitation > 4 }) {
                let hour = hourFormatter.string(from: heavyStart.time)
                let key: String.LocalizationValue = switch precipitationType(for: heavyStart.symbol) {
                case .snow: "weather.upcoming.heavySnow \(hour)"
                case .sleet: "weather.upcoming.heavySleet \(hour)"
                case .rain: "weather.upcoming.heavyRain \(hour)"
                }
                return UpcomingChange(
                    description: String(localized: key),
                    hour: hour,
                    severity: .caution
                )
            }
        }

        return nil
    }

    // MARK: - Outdoor Assessment

    /// One-line combined outdoor assessment based on temperature, wind, gusts, and precipitation.
    /// Answers the question: "Should I go outside, and what should I prepare for?"
    nonisolated static func outdoorAssessment(
        temperature: Double,
        windSpeed: Double,
        windGust: Double?,
        precipitation: Double,
        precipitationProbability: Double
    ) -> String {
        let wc = windChill(temperature: temperature, windSpeedMs: windSpeed)
        let effectiveTemp = wc ?? temperature
        let gustLevel = gustWarningLevel(windGust ?? windSpeed)
        let windLevel = windWarningLevel(windSpeed)
        let worstWind = max(gustLevel, windLevel)

        // Life-threatening conditions first
        if worstWind == .extreme {
            return String(localized: "weather.assessment.extreme")
        }
        if effectiveTemp < -25 {
            return String(localized: "weather.assessment.extremeCold")
        }

        // Dangerous conditions
        if worstWind == .danger {
            return String(localized: "weather.assessment.dangerousWind")
        }
        if effectiveTemp < -15 {
            return String(localized: "weather.assessment.veryCold")
        }

        // Caution
        if worstWind == .caution && precipitation > 1 {
            return String(localized: "weather.assessment.windAndRain")
        }
        if worstWind == .caution {
            return String(localized: "weather.assessment.windyCaution")
        }
        if precipitation > 4 || (precipitationProbability > 70 && precipitation > 1) {
            return String(localized: "weather.assessment.heavyPrecip")
        }
        if effectiveTemp < 0 {
            return String(localized: "weather.assessment.cold")
        }

        // Moderate
        if precipitationProbability > 50 {
            return String(localized: "weather.assessment.likelyRain")
        }
        if effectiveTemp < 10 {
            return String(localized: "weather.assessment.cool")
        }

        // Good conditions
        if precipitationProbability < 20 && windSpeed < 5.5 && effectiveTemp >= 10 {
            return String(localized: "weather.assessment.great")
        }

        return String(localized: "weather.assessment.good")
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
