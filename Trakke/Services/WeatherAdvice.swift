import Foundation
import CoreLocation

/// All non-network weather *advice* derived from raw `WeatherData`. Pure
/// `nonisolated` functions kept on `WeatherService` as a namespace so the
/// existing call sites do not need to change, but split off into their own
/// file because they are a logically separate concern from HTTP/cache/parse.
extension WeatherService {

    // MARK: - Wind Chill (Følt temperatur)

    /// Environment Canada wind chill formula. Returns nil when wind chill is not
    /// meaningful (temperature > 10°C or wind < 4.8 km/h).
    /// Brukes av intern logikk (vurdering, varsler). For display av "Føles som"
    /// bruk `apparentTemperature(...)` som dekker hele temperatur-spennet.
    nonisolated static func windChill(temperature: Double, windSpeedMs: Double) -> Double? {
        let windKmh = windSpeedMs * 3.6
        guard temperature <= 10, windKmh >= 4.8 else { return nil }
        let wc = 13.12 + 0.6215 * temperature
            - 11.37 * pow(windKmh, 0.16)
            + 0.3965 * temperature * pow(windKmh, 0.16)
        return wc
    }

    /// Apparent Temperature — Australian Bureau of Meteorology-formelen.
    /// Tar hensyn til både vind og luftfuktighet, og fungerer på alle
    /// temperaturer (ikke bare kulde slik windChill gjør). Brukes til "Føles
    /// som"-display i værkortet så brukeren ser en relevant verdi også i
    /// mildere vær.
    ///
    /// Formel: AT = T + 0.33·E − 0.70·WS − 4.00
    /// hvor E = (RH/100) · 6.105 · exp(17.27·T / (237.7 + T))
    nonisolated static func apparentTemperature(
        temperature: Double,
        windSpeedMs: Double,
        humidity: Double
    ) -> Double {
        let e = (humidity / 100.0) * 6.105 * exp((17.27 * temperature) / (237.7 + temperature))
        return temperature + 0.33 * e - 0.70 * windSpeedMs - 4.00
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

    static var windDirections: [String] { ["N", "NØ", "Ø", "SØ", "S", "SV", "V", "NV"] }
    static var windDirectionsFull: [String] { ["nord", "nordøst", "øst", "sørøst", "sør", "sørvest", "vest", "nordvest"] }

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
        case 0: String(localized: "weather.wind.context.north")
        case 1: String(localized: "weather.wind.context.northeast")
        case 2: String(localized: "weather.wind.context.east")
        case 3: String(localized: "weather.wind.context.southeast")
        case 4: String(localized: "weather.wind.context.south")
        case 5: String(localized: "weather.wind.context.southwest")
        case 6: String(localized: "weather.wind.context.west")
        case 7: String(localized: "weather.wind.context.northwest")
        default: ""
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

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH"
        return f
    }()

    // outdoorAssessment fjernet i mai 2026 — den tolket værdata for hardt
    // ("Mye vind. Ta vindtette klær på eksponerte strekninger.") og bommet
    // i tursammenheng. Brukerne ser de rå tallene + tooltipene istedet.
}
