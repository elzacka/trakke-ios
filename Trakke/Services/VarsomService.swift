import Foundation
import CoreLocation
import OSLog

// MARK: - Varsom Warning Data

struct VarsomWarning: Sendable, Identifiable {
    let id: String
    let type: WarningType
    let regionName: String
    let dangerLevel: Int // 0-5 (0 = not assessed, 1 = green, 2 = yellow, 3 = orange, 4 = red, 5 = extreme)
    let validFrom: Date
    let validTo: Date
    let mainText: String

    enum WarningType: String, Sendable {
        case avalanche
        case flood
    }

    var dangerColor: String {
        switch dangerLevel {
        case 0, 1: return "green"
        case 2: return "yellow"
        case 3: return "orange"
        case 4, 5: return "red"
        default: return "green"
        }
    }

    var dangerName: String {
        switch dangerLevel {
        case 0: return String(localized: "varsom.level.0")
        case 1: return String(localized: "varsom.level.1")
        case 2: return String(localized: "varsom.level.2")
        case 3: return String(localized: "varsom.level.3")
        case 4: return String(localized: "varsom.level.4")
        case 5: return String(localized: "varsom.level.5")
        default: return ""
        }
    }
}

// MARK: - Protocol

protocol VarsomFetching: Sendable {
    func fetchWarnings(at coordinate: CLLocationCoordinate2D) async -> [VarsomWarning]
    func clearCache() async
}

// MARK: - Varsom Service

actor VarsomService: VarsomFetching {
    private var cache: (warnings: [VarsomWarning], fetchedAt: Date, coordinate: CLLocationCoordinate2D)?
    private static let cacheTTL: TimeInterval = 3600 // 1 hour

    func clearCache() {
        cache = nil
    }

    func fetchWarnings(at coordinate: CLLocationCoordinate2D) async -> [VarsomWarning] {
        if let cached = cache,
           Date().timeIntervalSince(cached.fetchedAt) < Self.cacheTTL,
           abs(cached.coordinate.latitude - coordinate.latitude) < 0.1,
           abs(cached.coordinate.longitude - coordinate.longitude) < 0.1 {
            return cached.warnings
        }

        async let avalanche = fetchAvalanche(lat: coordinate.latitude, lon: coordinate.longitude)
        async let flood = fetchFlood(lat: coordinate.latitude, lon: coordinate.longitude)

        let warnings = await avalanche + flood
        cache = (warnings: warnings, fetchedAt: Date(), coordinate: coordinate)
        return warnings
    }

    // MARK: - Avalanche

    private func fetchAvalanche(lat: Double, lon: Double) async -> [VarsomWarning] {
        let truncLat = (lat * 10000).rounded() / 10000
        let truncLon = (lon * 10000).rounded() / 10000
        let urlString = "https://api01.nve.no/hydrology/forecast/avalanche/v6.3.0/api/AvalancheWarningByCoordinates/Detail/\(truncLat)/\(truncLon)/1"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let data = try await APIClient.fetchData(url: url, timeout: 15)
            let items = try JSONDecoder().decode([AvalancheResponse].self, from: data)
            return items.compactMap { item -> VarsomWarning? in
                guard item.dangerLevel > 0,
                      let from = Self.parseDate(item.ValidFrom),
                      let to = Self.parseDate(item.ValidTo) else { return nil }
                return VarsomWarning(
                    id: "avalanche-\(item.RegionId)-\(item.ValidFrom)",
                    type: .avalanche,
                    regionName: item.RegionName,
                    dangerLevel: item.dangerLevel,
                    validFrom: from,
                    validTo: to,
                    mainText: item.MainText ?? ""
                )
            }
        } catch {
            Logger.weather.error("Varsom avalanche fetch error: \(error, privacy: .private)")
            return []
        }
    }

    // MARK: - Flood

    private func fetchFlood(lat: Double, lon: Double) async -> [VarsomWarning] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = Self.urlDateFormatter.string(from: today)
        guard let endDate = calendar.date(byAdding: .day, value: 3, to: today) else { return [] }
        let endStr = Self.urlDateFormatter.string(from: endDate)

        let urlString = "https://api01.nve.no/hydrology/forecast/flood/v1.0.6/api/Warning/County/nb/\(startDate)/\(endStr)"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let data = try await APIClient.fetchData(url: url, timeout: 15)
            let items = try JSONDecoder().decode([FloodResponse].self, from: data)
            return items.compactMap { item -> VarsomWarning? in
                guard item.activityLevelInt > 1,
                      let fromStr = item.ValidFrom, let from = Self.parseDate(fromStr),
                      let toStr = item.ValidTo, let to = Self.parseDate(toStr) else { return nil }
                return VarsomWarning(
                    id: "flood-\(item.CountyName ?? "")-\(fromStr)",
                    type: .flood,
                    regionName: item.CountyName ?? "",
                    dangerLevel: item.activityLevelInt,
                    validFrom: from,
                    validTo: to,
                    mainText: item.MainText ?? ""
                )
            }
        } catch {
            Logger.weather.error("Varsom flood fetch error: \(error, privacy: .private)")
            return []
        }
    }

    // MARK: - Helpers

    private nonisolated(unsafe) static let iso8601 = ISO8601DateFormatter()

    private static let urlDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Oslo")
        return f
    }()

    private static let localDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Oslo")
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        // NVE uses "2026-04-05T07:00:00" format (no timezone)
        let cleaned = string.replacingOccurrences(of: "+00:00", with: "Z")
        if let date = iso8601.date(from: cleaned) { return date }
        return localDateTimeFormatter.date(from: string)
    }

}

// MARK: - API Response Types

private struct AvalancheResponse: Decodable {
    let RegionId: Int
    let RegionName: String
    let dangerLevel: Int
    let ValidFrom: String
    let ValidTo: String
    let MainText: String?

    private enum CodingKeys: String, CodingKey {
        case RegionId, RegionName, DangerLevel, ValidFrom, ValidTo, MainText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        RegionId = try container.decode(Int.self, forKey: .RegionId)
        RegionName = try container.decode(String.self, forKey: .RegionName)
        // API returns DangerLevel as String or Int depending on context
        if let intVal = try? container.decode(Int.self, forKey: .DangerLevel) {
            dangerLevel = intVal
        } else if let strVal = try? container.decode(String.self, forKey: .DangerLevel),
                  let parsed = Int(strVal) {
            dangerLevel = parsed
        } else {
            dangerLevel = 0
        }
        ValidFrom = try container.decode(String.self, forKey: .ValidFrom)
        ValidTo = try container.decode(String.self, forKey: .ValidTo)
        MainText = try container.decodeIfPresent(String.self, forKey: .MainText)
    }
}

private struct FloodResponse: Decodable {
    let CountyName: String?
    let ActivityLevel: String?
    let ValidFrom: String?
    let ValidTo: String?
    let MainText: String?

    var activityLevelInt: Int {
        guard let str = ActivityLevel else { return 0 }
        return Int(str) ?? 0
    }
}
