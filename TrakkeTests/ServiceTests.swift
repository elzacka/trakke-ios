import Testing
import Foundation
@testable import Trakke

// MARK: - VarsomService Tests

@Test func varsomWarningDangerName() {
    let levels = [0, 1, 2, 3, 4, 5]
    for level in levels {
        let warning = VarsomWarning(
            id: "test-\(level)",
            type: .avalanche,
            regionName: "Jotunheimen",
            dangerLevel: level,
            validFrom: Date(),
            validTo: Date().addingTimeInterval(86400),
            mainText: ""
        )
        #expect(!warning.dangerName.isEmpty || level > 5, "Level \(level) should have a name")
    }
}

@Test func varsomWarningDangerColor() {
    let warning2 = VarsomWarning(
        id: "test-2", type: .avalanche, regionName: "Lyngen",
        dangerLevel: 2, validFrom: Date(), validTo: Date(), mainText: ""
    )
    #expect(warning2.dangerColor == "yellow")

    let warning4 = VarsomWarning(
        id: "test-4", type: .flood, regionName: "Troms",
        dangerLevel: 4, validFrom: Date(), validTo: Date(), mainText: ""
    )
    #expect(warning4.dangerColor == "red")

    let warning1 = VarsomWarning(
        id: "test-1", type: .avalanche, regionName: "Nordland",
        dangerLevel: 1, validFrom: Date(), validTo: Date(), mainText: ""
    )
    #expect(warning1.dangerColor == "green")
}

@Test func varsomWarningTypes() {
    #expect(VarsomWarning.WarningType.avalanche.rawValue == "avalanche")
    #expect(VarsomWarning.WarningType.flood.rawValue == "flood")
}

@Test func varsomServiceCacheClears() async {
    let service = VarsomService()
    await service.clearCache()
}

// MARK: - WaterTemperatureService Tests

@Test func waterTemperatureSourceTypes() {
    let ocean = WaterTemperature(temperature: 12.5, source: .oceanForecast, name: nil, fetchedAt: .now)
    let bathing = WaterTemperature(temperature: 18.0, source: .bathingSpot, name: "Huk", fetchedAt: .now)

    switch ocean.source {
    case .oceanForecast: break
    case .bathingSpot: Issue.record("Expected oceanForecast")
    }

    switch bathing.source {
    case .bathingSpot: break
    case .oceanForecast: Issue.record("Expected bathingSpot")
    }

    #expect(bathing.name == "Huk")
    #expect(ocean.name == nil)
}

@Test func waterTemperatureResultComposition() {
    let ocean = WaterTemperature(temperature: 8.3, source: .oceanForecast, name: nil, fetchedAt: .now)
    let spots = [
        WaterTemperature(temperature: 15.2, source: .bathingSpot, name: "Sjobad", fetchedAt: .now),
        WaterTemperature(temperature: 16.1, source: .bathingSpot, name: "Paradisbukta", fetchedAt: .now),
    ]
    let coord = CLLocationCoordinate2D(latitude: 59.89, longitude: 10.73)
    let result = WaterTemperatureResult(
        oceanTemperature: ocean,
        bathingSpots: spots,
        coordinate: coord,
        fetchedAt: .now
    )

    #expect(result.oceanTemperature?.temperature == 8.3)
    #expect(result.bathingSpots.count == 2)
    #expect(result.coordinate.latitude == 59.89)
}

@Test func waterTemperatureServiceCacheClears() async {
    let service = WaterTemperatureService()
    await service.clearCache()
}

// MARK: - AirQualityService Tests

@Test func airQualityServiceCacheClears() async {
    let service = AirQualityService()
    await service.clearCache()
}

// MARK: - RemoteArticleService Tests

@Test func remoteArticleServiceCacheClears() async {
    let service = RemoteArticleService()
    let articles = await service.cachedArticles()
    #expect(articles.isEmpty, "Fresh service should have no cached articles")
    await service.clearCache()
}

import CoreLocation
