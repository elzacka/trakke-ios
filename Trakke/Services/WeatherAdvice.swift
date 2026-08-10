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

    /// Apparent Temperature – Australian Bureau of Meteorology-formelen.
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

    // MARK: - Wind Direction

    static var windDirections: [String] { ["N", "NØ", "Ø", "SØ", "S", "SV", "V", "NV"] }
    static var windDirectionsFull: [String] { ["nord", "nordøst", "øst", "sørøst", "sør", "sørvest", "vest", "nordvest"] }

    nonisolated static func windDirectionName(_ degrees: Double) -> String {
        let index = ((Int((degrees / 45).rounded()) % 8) + 8) % 8
        return windDirections[index]
    }

    /// Full Norwegian name for wind direction (e.g., "sørøst"). Vises i vindraden.
    nonisolated static func windDirectionFullName(_ degrees: Double) -> String {
        let index = ((Int((degrees / 45).rounded()) % 8) + 8) % 8
        return windDirectionsFull[index]
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
                let hour = hourString(from: precipStart.time)
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
                let hour = hourString(from: point.time)
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
                let hour = hourString(from: heavyStart.time)
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

    /// DateFormatter er ikke trådsikker og funksjonene her er nonisolated –
    /// lag formatteren per kall i stedet for å dele en global instans.
    private static func hourString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH"
        return f.string(from: date)
    }

    // outdoorAssessment fjernet i mai 2026 – den tolket værdata for hardt
    // ("Mye vind. Ta vindtette klær på eksponerte strekninger.") og bommet
    // i tursammenheng. Brukerne ser de rå tallene + tooltipene istedet.
}
