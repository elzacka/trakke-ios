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
    var varsomWarnings: [VarsomWarning] = []
    var airQuality: AirQualityData?

    private let service: any WeatherFetching
    private let waterService: any WaterTemperatureFetching
    private let varsomService: any VarsomFetching
    private let airQualityService: any AirQualityFetching
    private var lastFetchCoordinate: CLLocationCoordinate2D?

    init(
        service: any WeatherFetching = WeatherService(),
        waterService: any WaterTemperatureFetching = WaterTemperatureService(),
        varsomService: any VarsomFetching = VarsomService(),
        airQualityService: any AirQualityFetching = AirQualityService()
    ) {
        self.service = service
        self.waterService = waterService
        self.varsomService = varsomService
        self.airQualityService = airQualityService
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

                // Varsom warnings and air quality are best-effort
                varsomWarnings = await varsomService.fetchWarnings(at: coordinate)
                airQuality = try? await airQualityService.getAirQuality(
                    lat: coordinate.latitude, lon: coordinate.longitude
                )

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

    func clearCaches() async {
        await service.clearCache()
        await waterService.clearCache()
        await varsomService.clearCache()
        await airQualityService.clearCache()
        forecast = nil
        waterTemperature = nil
        varsomWarnings = []
        airQuality = nil
        lastFetchCoordinate = nil
    }

    // MARK: - Norwegian Condition Text

    nonisolated static func conditionText(for metSymbol: String) -> String {
        let base = metSymbol.replacingOccurrences(of: "_polartwilight", with: "")

        // Names match Yr's official symbol names:
        // https://hjelp.yr.no/hc/no/articles/203786121-Værsymbolene-på-Yr
        switch base {
        case "clearsky_day", "clearsky_night": return String(localized: "weather.clearsky")
        case "fair_day", "fair_night": return String(localized: "weather.fair")
        case "partlycloudy_day", "partlycloudy_night": return String(localized: "weather.partlycloudy")
        case "cloudy": return String(localized: "weather.cloudy")
        case "fog": return String(localized: "weather.fog")
        // Rain
        case "lightrain": return String(localized: "weather.lightrain")
        case "rain": return String(localized: "weather.rain")
        case "heavyrain": return String(localized: "weather.heavyrain")
        case "lightrainshowers_day", "lightrainshowers_night": return String(localized: "weather.lightrainshowers")
        case "rainshowers_day", "rainshowers_night": return String(localized: "weather.rainshowers")
        case "heavyrainshowers_day", "heavyrainshowers_night": return String(localized: "weather.heavyrainshowers")
        // Sleet
        case "lightsleet": return String(localized: "weather.lightsleet")
        case "sleet": return String(localized: "weather.sleet")
        case "heavysleet": return String(localized: "weather.heavysleet")
        case "lightsleetshowers_day", "lightsleetshowers_night": return String(localized: "weather.lightsleetshowers")
        case "sleetshowers_day", "sleetshowers_night": return String(localized: "weather.sleetshowers")
        case "heavysleetshowers_day", "heavysleetshowers_night": return String(localized: "weather.heavysleetshowers")
        // Snow
        case "lightsnow": return String(localized: "weather.lightsnow")
        case "snow": return String(localized: "weather.snow")
        case "heavysnow": return String(localized: "weather.heavysnow")
        case "lightsnowshowers_day", "lightsnowshowers_night": return String(localized: "weather.lightsnowshowers")
        case "snowshowers_day", "snowshowers_night": return String(localized: "weather.snowshowers")
        case "heavysnowshowers_day", "heavysnowshowers_night": return String(localized: "weather.heavysnowshowers")
        // Rain + thunder
        case "lightrainandthunder": return String(localized: "weather.lightrainandthunder")
        case "rainandthunder": return String(localized: "weather.rainandthunder")
        case "heavyrainandthunder": return String(localized: "weather.heavyrainandthunder")
        case "lightrainshowersandthunder_day", "lightrainshowersandthunder_night": return String(localized: "weather.lightrainshowersandthunder")
        case "rainshowersandthunder_day", "rainshowersandthunder_night": return String(localized: "weather.rainshowersandthunder")
        case "heavyrainshowersandthunder_day", "heavyrainshowersandthunder_night": return String(localized: "weather.heavyrainshowersandthunder")
        // Snow + thunder (MET API uses double-s typo in lightssnow/lightssleet)
        case "lightsnowandthunder": return String(localized: "weather.lightsnowandthunder")
        case "snowandthunder": return String(localized: "weather.snowandthunder")
        case "heavysnowandthunder": return String(localized: "weather.heavysnowandthunder")
        case "lightsnowshowersandthunder_day", "lightssnowshowersandthunder_day",
             "lightsnowshowersandthunder_night", "lightssnowshowersandthunder_night": return String(localized: "weather.lightsnowshowersandthunder")
        case "snowshowersandthunder_day", "snowshowersandthunder_night": return String(localized: "weather.snowshowersandthunder")
        case "heavysnowshowersandthunder_day", "heavysnowshowersandthunder_night": return String(localized: "weather.heavysnowshowersandthunder")
        // Sleet + thunder
        case "lightsleetandthunder": return String(localized: "weather.lightsleetandthunder")
        case "sleetandthunder": return String(localized: "weather.sleetandthunder")
        case "heavysleetandthunder": return String(localized: "weather.heavysleetandthunder")
        case "lightsleetshowersandthunder_day", "lightssleetshowersandthunder_day",
             "lightsleetshowersandthunder_night", "lightssleetshowersandthunder_night": return String(localized: "weather.lightsleetshowersandthunder")
        case "sleetshowersandthunder_day", "sleetshowersandthunder_night": return String(localized: "weather.sleetshowersandthunder")
        case "heavysleetshowersandthunder_day", "heavysleetshowersandthunder_night": return String(localized: "weather.heavysleetshowersandthunder")
        default:
            assertionFailure("Unmapped MET weather symbol: \(base)")
            return String(localized: "weather.cloudy")
        }
    }
}
