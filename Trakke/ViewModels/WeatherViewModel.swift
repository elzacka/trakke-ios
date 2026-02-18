import Foundation
import CoreLocation

@MainActor
@Observable
final class WeatherViewModel {
    var forecast: WeatherForecast?
    var isLoading = false
    var error: String?

    private let service = WeatherService()
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private var fetchTask: Task<Void, Never>?
    private static let debounceInterval: Duration = .seconds(2)

    // MARK: - Fetch

    func fetchForecast(for coordinate: CLLocationCoordinate2D) {
        // Skip if same location (within ~1km)
        if let last = lastFetchCoordinate {
            let distance = Haversine.distance(from: last, to: coordinate)
            if distance < 1000, forecast != nil { return }
        }

        // Debounce rapid viewport changes during panning
        fetchTask?.cancel()
        fetchTask = Task {
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }

            self.lastFetchCoordinate = coordinate
            self.isLoading = true
            self.error = nil

            do {
                let result = try await self.service.getForecast(lat: coordinate.latitude, lon: coordinate.longitude)
                guard !Task.isCancelled else { return }
                self.forecast = result
                self.isLoading = false
            } catch is CancellationError {
                // Debounce cancelled, ignore
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func refresh() {
        guard let coord = lastFetchCoordinate else { return }
        lastFetchCoordinate = nil
        fetchForecast(for: coord)
    }

    // MARK: - Norwegian Condition Text

    nonisolated static func conditionText(for metSymbol: String) -> String {
        let base = metSymbol.replacingOccurrences(of: "_polartwilight", with: "")

        switch base {
        case "clearsky_day", "clearsky_night": return "Klarvær"
        case "fair_day", "fair_night": return "Lettskyet"
        case "partlycloudy_day", "partlycloudy_night": return "Delvis skyet"
        case "cloudy": return "Overskyet"
        case "fog": return "Tåke"
        case "lightrain": return "Lett regn"
        case "rain": return "Regn"
        case "heavyrain": return "Kraftig regn"
        case "lightrainshowers_day", "lightrainshowers_night": return "Lette regnbyger"
        case "rainshowers_day", "rainshowers_night": return "Regnbyger"
        case "heavyrainshowers_day", "heavyrainshowers_night": return "Kraftige regnbyger"
        case "sleet", "lightsleet": return "Sludd"
        case "heavysleet": return "Kraftig sludd"
        case "sleetshowers_day", "lightsleetshowers_day",
             "sleetshowers_night", "lightsleetshowers_night": return "Sluddbyger"
        case "snow", "lightsnow": return "Snø"
        case "heavysnow": return "Kraftig snøfall"
        case "snowshowers_day", "lightsnowshowers_day",
             "snowshowers_night", "lightsnowshowers_night": return "Snøbyger"
        case "rainandthunder", "lightrainandthunder", "heavyrainandthunder": return "Regn og torden"
        case "rainshowersandthunder_day", "lightrainshowersandthunder_day",
             "rainshowersandthunder_night", "lightrainshowersandthunder_night": return "Regnbyger og torden"
        case "snowandthunder", "lightsnowandthunder", "heavysnowandthunder": return "Snø og torden"
        case "sleetandthunder", "lightsleetandthunder", "heavysleetandthunder": return "Sludd og torden"
        default: return "Overskyet"
        }
    }
}
