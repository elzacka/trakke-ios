import Foundation
import CoreLocation

@MainActor
@Observable
final class WeatherViewModel {
    var forecast: WeatherForecast?
    var isLoading = false
    var error: String?
    var daylight: SolarCalculator.DaylightInfo?
    var waterTemperature: WaterTemperatureResult?

    private let service: any WeatherFetching
    private let waterService: any WaterTemperatureFetching
    private var lastFetchCoordinate: CLLocationCoordinate2D?

    init(
        service: any WeatherFetching = WeatherService(),
        waterService: any WaterTemperatureFetching = WaterTemperatureService()
    ) {
        self.service = service
        self.waterService = waterService
    }
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
        fetchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled, let self else { return }

            lastFetchCoordinate = coordinate
            isLoading = true
            error = nil
            daylight = SolarCalculator.calculate(for: coordinate)

            do {
                async let weatherResult = service.getForecast(lat: coordinate.latitude, lon: coordinate.longitude)
                async let waterResult = waterService.getWaterTemperature(lat: coordinate.latitude, lon: coordinate.longitude)

                let weather = try await weatherResult
                guard !Task.isCancelled else { return }
                forecast = weather

                // Water temperature is best-effort — never block weather display
                waterTemperature = try? await waterResult

                isLoading = false
            } catch is CancellationError {
                // Debounce cancelled, ignore
            } catch {
                guard !Task.isCancelled else { return }
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

    // MARK: - Norwegian Condition Text

    nonisolated static func conditionText(for metSymbol: String) -> String {
        let base = metSymbol.replacingOccurrences(of: "_polartwilight", with: "")

        switch base {
        case "clearsky_day", "clearsky_night": return String(localized: "weather.clearsky")
        case "fair_day", "fair_night": return String(localized: "weather.fair")
        case "partlycloudy_day", "partlycloudy_night": return String(localized: "weather.partlycloudy")
        case "cloudy": return String(localized: "weather.cloudy")
        case "fog": return String(localized: "weather.fog")
        case "lightrain": return String(localized: "weather.lightrain")
        case "rain": return String(localized: "weather.rain")
        case "heavyrain": return String(localized: "weather.heavyrain")
        case "lightrainshowers_day", "lightrainshowers_night": return String(localized: "weather.lightrainshowers")
        case "rainshowers_day", "rainshowers_night": return String(localized: "weather.rainshowers")
        case "heavyrainshowers_day", "heavyrainshowers_night": return String(localized: "weather.heavyrainshowers")
        case "sleet", "lightsleet": return String(localized: "weather.sleet")
        case "heavysleet": return String(localized: "weather.heavysleet")
        case "sleetshowers_day", "lightsleetshowers_day",
             "sleetshowers_night", "lightsleetshowers_night": return String(localized: "weather.sleetshowers")
        case "snow", "lightsnow": return String(localized: "weather.snow")
        case "heavysnow": return String(localized: "weather.heavysnow")
        case "snowshowers_day", "lightsnowshowers_day",
             "snowshowers_night", "lightsnowshowers_night": return String(localized: "weather.snowshowers")
        case "rainandthunder", "lightrainandthunder", "heavyrainandthunder": return String(localized: "weather.rainandthunder")
        case "rainshowersandthunder_day", "lightrainshowersandthunder_day",
             "rainshowersandthunder_night", "lightrainshowersandthunder_night": return String(localized: "weather.rainshowersandthunder")
        case "snowandthunder", "lightsnowandthunder", "heavysnowandthunder": return String(localized: "weather.snowandthunder")
        case "sleetandthunder", "lightsleetandthunder", "heavysleetandthunder": return String(localized: "weather.sleetandthunder")
        default: return String(localized: "weather.cloudy")
        }
    }
}
