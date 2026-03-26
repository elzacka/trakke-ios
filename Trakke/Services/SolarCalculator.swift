import Foundation
import CoreLocation

/// Calculates sunrise, sunset, and remaining daylight using the NOAA solar equations.
/// No external API needed — pure math based on date, latitude, and longitude.
enum SolarCalculator {

    struct DaylightInfo: Sendable {
        let sunrise: Date
        let sunset: Date
        let remainingDaylight: TimeInterval

        var sunriseFormatted: String {
            Self.timeFormatter.string(from: sunrise)
        }

        var sunsetFormatted: String {
            Self.timeFormatter.string(from: sunset)
        }

        var remainingDaylightFormatted: String {
            let hours = Int(remainingDaylight) / 3600
            let minutes = (Int(remainingDaylight) % 3600) / 60
            if remainingDaylight <= 0 {
                return "0t 0min"
            }
            return "\(hours)t \(minutes)min"
        }

        var isDaytime: Bool {
            remainingDaylight > 0
        }

        private static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            f.timeZone = .current
            return f
        }()
    }

    /// Calculate sunrise, sunset, and remaining daylight for a given coordinate and date.
    /// Uses NOAA simplified solar position algorithm.
    static func calculate(for coordinate: CLLocationCoordinate2D, date: Date = Date()) -> DaylightInfo? {
        let calendar = Calendar.current
        let timeZone = TimeZone.current

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1


        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // Fractional year (radians)
        let totalDays = Double(calendar.range(of: .day, in: .year, for: date)?.count ?? 365)
        let gamma = 2.0 * .pi / totalDays * (Double(dayOfYear) - 1.0 + 0.5)

        // Equation of time (minutes)
        let eqtime = 229.18 * (0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2.0 * gamma)
            - 0.040849 * sin(2.0 * gamma))

        // Solar declination (radians)
        let decl = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2.0 * gamma)
            + 0.000907 * sin(2.0 * gamma)
            - 0.002697 * cos(3.0 * gamma)
            + 0.00148 * sin(3.0 * gamma)

        let latRad = lat * .pi / 180.0

        // Hour angle for sunrise/sunset (degrees)
        let cosHA = (cos(90.833 * .pi / 180.0) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)

        // Polar night or midnight sun
        guard cosHA >= -1.0 && cosHA <= 1.0 else {
            // If cosHA < -1, midnight sun; if > 1, polar night
            if cosHA < -1.0 {
                // Midnight sun — full 24h daylight
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
                let remaining = max(0, endOfDay.timeIntervalSince(date))
                return DaylightInfo(
                    sunrise: startOfDay,
                    sunset: endOfDay,
                    remainingDaylight: remaining
                )
            }
            // Polar night — no daylight
            let now = date
            return DaylightInfo(sunrise: now, sunset: now, remainingDaylight: 0)
        }

        let ha = acos(cosHA) * 180.0 / .pi

        // Timezone offset in hours
        let tzOffset = Double(timeZone.secondsFromGMT(for: date)) / 3600.0

        // Sunrise and sunset in minutes from midnight UTC
        let sunriseMins = 720.0 - 4.0 * (lon + ha) - eqtime
        let sunsetMins = 720.0 - 4.0 * (lon - ha) - eqtime

        // Convert to local time
        let sunriseLocal = sunriseMins + tzOffset * 60.0
        let sunsetLocal = sunsetMins + tzOffset * 60.0

        let startOfDay = calendar.startOfDay(for: date)
        guard let sunrise = calendar.date(byAdding: .second, value: Int(sunriseLocal * 60), to: startOfDay),
              let sunset = calendar.date(byAdding: .second, value: Int(sunsetLocal * 60), to: startOfDay) else {
            return nil
        }

        let remaining = max(0, sunset.timeIntervalSince(date))

        return DaylightInfo(
            sunrise: sunrise,
            sunset: sunset,
            remainingDaylight: remaining
        )
    }
}
