import Foundation
import CoreLocation
import OSLog

// MARK: - Air Quality Data

struct AirQualityData: Sendable {
    let aqi: Double
    let aqiClass: AQIClass
    let pm25: Double?
    let pm10: Double?
    let o3: Double?
    let no2: Double?
    let locationName: String
    let time: Date
}

enum AQIClass: Int, Sendable {
    case low = 1        // 1.0-2.0: Lite forurensning
    case moderate = 2   // 2.0-3.0: Moderat
    case high = 3       // 3.0-4.0: Høy
    case veryHigh = 4   // 4.0-5.0: Svært høy

    init(aqi: Double) {
        switch aqi {
        case ..<2.0: self = .low
        case ..<3.0: self = .moderate
        case ..<4.0: self = .high
        default: self = .veryHigh
        }
    }

    var norwegianName: String {
        switch self {
        case .low: return String(localized: "weather.aqi.low")
        case .moderate: return String(localized: "weather.aqi.moderate")
        case .high: return String(localized: "weather.aqi.high")
        case .veryHigh: return String(localized: "weather.aqi.veryHigh")
        }
    }

    var healthAdvice: String {
        switch self {
        case .low: return String(localized: "weather.aqi.advice.low")
        case .moderate: return String(localized: "weather.aqi.advice.moderate")
        case .high: return String(localized: "weather.aqi.advice.high")
        case .veryHigh: return String(localized: "weather.aqi.advice.veryHigh")
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(hex: "3F9F41")
        case .moderate: return Color(hex: "FFCB00")
        case .high: return Color(hex: "C13500")
        case .veryHigh: return Color(hex: "4900AC")
        }
    }
}

import SwiftUI

// MARK: - Air Quality Service

/// Fetches air quality forecasts from Meteorologisk institutt's airqualityforecast API.
/// Respects MET API ToS: uses If-Modified-Since/Expires headers for caching.
actor AirQualityService {
    private static let baseURL = "https://api.met.no/weatherapi/airqualityforecast/0.1/"

    private var cache: (key: String, data: AirQualityData, expiresAt: Date, lastModified: String?)?
    private static let fallbackTTL: TimeInterval = 3600

    private let decoder = JSONDecoder()

    // Actor-isolated formatter — safe without nonisolated(unsafe)
    private let iso8601 = ISO8601DateFormatter()

    func getAirQuality(lat: Double, lon: Double) async throws -> AirQualityData? {
        // 2dp precision for data minimization — air quality is per grunnkrets/kommune
        let cacheKey = String(format: "%.2f,%.2f", lat, lon)

        // Return cached data if not expired
        if let cache, cache.key == cacheKey, Date() < cache.expiresAt {
            return cache.data
        }

        // Try grunnkrets first (finest resolution), fall back to kommune on failure
        if let result = await fetchAQ(lat: lat, lon: lon, areaclass: "grunnkrets") {
            return result
        }
        if let result = await fetchAQ(lat: lat, lon: lon, areaclass: "kommune") {
            return result
        }
        return nil
    }

    private func fetchAQ(lat: Double, lon: Double, areaclass: String) async -> AirQualityData? {
        guard var components = URLComponents(string: Self.baseURL) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", lat)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", lon)),
            URLQueryItem(name: "areaclass", value: areaclass),
            URLQueryItem(name: "filter_vars", value: "AQI,pm10_concentration,pm25_concentration,o3_concentration,no2_concentration"),
        ]

        guard let url = components.url else { return nil }

        let cacheKey = String(format: "%.2f,%.2f", lat, lon)
        let ifModifiedSince = (cache?.key == cacheKey) ? cache?.lastModified : nil

        let result: ConditionalFetchResult
        do {
            result = try await APIClient.fetchDataConditional(
                url: url,
                ifModifiedSince: ifModifiedSince
            )
        } catch {
            Logger.weather.warning("Air quality fetch (\(areaclass)) failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }

        if result.notModified, let cache, cache.key == cacheKey {
            let newExpiry = result.expires(fallbackTTL: Self.fallbackTTL)
            self.cache = (key: cacheKey, data: cache.data, expiresAt: newExpiry, lastModified: cache.lastModified)
            return cache.data
        }

        guard result.ok else { return nil }

        guard let response = try? decoder.decode(AQResponse.self, from: result.data) else {
            return nil
        }

        // Find current or nearest future time entry
        let now = Date()
        guard let entry = response.data.time.first(where: {
            guard let time = iso8601.date(from: $0.from) else { return false }
            return time >= now.addingTimeInterval(-1800)
        }) ?? response.data.time.first else {
            return nil
        }

        guard let aqiValue = entry.variables["AQI"]?.value,
              let time = iso8601.date(from: entry.from) else {
            return nil
        }

        let aqResult = AirQualityData(
            aqi: aqiValue,
            aqiClass: AQIClass(aqi: aqiValue),
            pm25: entry.variables["pm25_concentration"]?.value ?? nil,
            pm10: entry.variables["pm10_concentration"]?.value ?? nil,
            o3: entry.variables["o3_concentration"]?.value ?? nil,
            no2: entry.variables["no2_concentration"]?.value ?? nil,
            locationName: response.meta.location.name,
            time: time
        )

        let expiresAt = result.expires(fallbackTTL: Self.fallbackTTL)
        cache = (key: cacheKey, data: aqResult, expiresAt: expiresAt, lastModified: result.lastModified)

        return aqResult
    }

    func clearCache() {
        cache = nil
    }
}

// MARK: - API Response Models

private struct AQResponse: Decodable {
    let meta: AQMeta
    let data: AQData
}

private struct AQMeta: Decodable {
    let location: AQLocation
}

private struct AQLocation: Decodable {
    let name: String
}

private struct AQData: Decodable {
    let time: [AQTimeEntry]
}

private struct AQTimeEntry: Decodable {
    let from: String
    let to: String
    let variables: [String: AQVariable]
}

private struct AQVariable: Decodable {
    let value: Double?
    let units: String
}
