import Foundation
import CoreLocation

@MainActor
@Observable
final class WeatherViewModel {
    var forecast: WeatherForecast?
    var isLoading = false
    var error: String?
    var selectedDayIndex: Int?

    private let service = WeatherService()
    private var lastFetchCoordinate: CLLocationCoordinate2D?

    // MARK: - Fetch

    func fetchForecast(for coordinate: CLLocationCoordinate2D) {
        // Skip if same location (within ~1km)
        if let last = lastFetchCoordinate {
            let distance = Haversine.distance(from: last, to: coordinate)
            if distance < 1000, forecast != nil { return }
        }

        lastFetchCoordinate = coordinate
        isLoading = true
        error = nil

        Task {
            do {
                let result = try await service.getForecast(lat: coordinate.latitude, lon: coordinate.longitude)
                forecast = result
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func refresh() {
        guard let coord = lastFetchCoordinate else { return }
        lastFetchCoordinate = nil
        fetchForecast(for: coord)
    }

    // MARK: - Day Drill-Down

    var selectedDay: WeatherData? {
        guard let index = selectedDayIndex,
              let daily = forecast?.daily,
              index < daily.count else { return nil }
        return daily[index]
    }

    func selectDay(_ index: Int) {
        selectedDayIndex = index
    }

    func clearDaySelection() {
        selectedDayIndex = nil
    }

    // MARK: - Hourly for Selected Day

    var hoursForSelectedDay: [WeatherData] {
        guard let index = selectedDayIndex,
              let daily = forecast?.daily,
              index < daily.count,
              let hourly = forecast?.hourly else { return [] }

        let dayDate = daily[index].time
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        return hourly.filter { $0.time >= dayStart && $0.time < dayEnd }
    }

    // MARK: - Weather Symbol Mapping

    nonisolated static func sfSymbol(for metSymbol: String) -> String {
        let base = metSymbol.replacingOccurrences(of: "_polartwilight", with: "")

        switch base {
        case "clearsky_day": return "sun.max.fill"
        case "clearsky_night": return "moon.stars.fill"
        case "fair_day": return "sun.min.fill"
        case "fair_night": return "moon.fill"
        case "partlycloudy_day": return "cloud.sun.fill"
        case "partlycloudy_night": return "cloud.moon.fill"
        case "cloudy": return "cloud.fill"
        case "fog": return "cloud.fog.fill"
        case "lightrain", "rain": return "cloud.rain.fill"
        case "heavyrain": return "cloud.heavyrain.fill"
        case "lightrainshowers_day", "rainshowers_day": return "cloud.sun.rain.fill"
        case "lightrainshowers_night", "rainshowers_night": return "cloud.moon.rain.fill"
        case "heavyrainshowers_day": return "cloud.sun.rain.fill"
        case "heavyrainshowers_night": return "cloud.moon.rain.fill"
        case "sleet", "lightsleet", "heavysleet": return "cloud.sleet.fill"
        case "sleetshowers_day", "lightsleetshowers_day": return "cloud.sun.sleet.fill"
        case "sleetshowers_night", "lightsleetshowers_night": return "cloud.moon.sleet.fill"
        case "snow", "lightsnow", "heavysnow": return "cloud.snow.fill"
        case "snowshowers_day", "lightsnowshowers_day": return "cloud.sun.snow.fill"
        case "snowshowers_night", "lightsnowshowers_night": return "cloud.moon.snow.fill"
        case "rainandthunder", "lightrainandthunder", "heavyrainandthunder": return "cloud.bolt.rain.fill"
        case "rainshowersandthunder_day", "lightrainshowersandthunder_day": return "cloud.sun.bolt.fill"
        case "rainshowersandthunder_night", "lightrainshowersandthunder_night": return "cloud.moon.bolt.fill"
        case "snowandthunder", "lightsnowandthunder", "heavysnowandthunder": return "cloud.bolt.fill"
        case "sleetandthunder", "lightsleetandthunder", "heavysleetandthunder": return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }
}
