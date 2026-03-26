import Testing
import Foundation
import CoreLocation
@testable import Trakke

// MARK: - SolarCalculator Tests

@Test func solarCalculatorOsloSpringEquinox() {
    // March 20, 2026 — roughly equal day/night
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
    let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 12))!

    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let result = SolarCalculator.calculate(for: oslo, date: date)

    #expect(result != nil)
    guard let info = result else { return }

    // Sunrise should be around 06:00-07:00 local
    let sunriseHour = calendar.component(.hour, from: info.sunrise)
    #expect(sunriseHour >= 5 && sunriseHour <= 8)

    // Sunset should be around 18:00-19:30 local
    let sunsetHour = calendar.component(.hour, from: info.sunset)
    #expect(sunsetHour >= 17 && sunsetHour <= 20)

    // At noon, there should be remaining daylight
    #expect(info.remainingDaylight > 0)
    #expect(info.isDaytime)
}

@Test func solarCalculatorPolarNight() {
    // December 21 at Hammerfest (70.6634 N) — polar night
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
    let date = calendar.date(from: DateComponents(year: 2025, month: 12, day: 21, hour: 12))!

    let hammerfest = CLLocationCoordinate2D(latitude: 70.6634, longitude: 23.6821)
    let result = SolarCalculator.calculate(for: hammerfest, date: date)

    #expect(result != nil)
    guard let info = result else { return }

    // During polar night, remaining daylight should be 0
    #expect(info.remainingDaylight == 0)
    #expect(!info.isDaytime)
}

@Test func solarCalculatorMidnightSun() {
    // June 21 at Hammerfest (70.6634 N) — midnight sun
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
    let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!

    let hammerfest = CLLocationCoordinate2D(latitude: 70.6634, longitude: 23.6821)
    let result = SolarCalculator.calculate(for: hammerfest, date: date)

    #expect(result != nil)
    guard let info = result else { return }

    // Midnight sun means daylight remaining > 0 and it's daytime
    #expect(info.isDaytime)
    #expect(info.remainingDaylight > 0)
}

@Test func solarCalculatorDaylightFormatting() {
    // Test remainingDaylightFormatted
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
    let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 10))!

    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let result = SolarCalculator.calculate(for: oslo, date: date)

    #expect(result != nil)
    guard let info = result else { return }

    // At 10 AM in June in Oslo, there should be many hours of daylight remaining
    let formatted = info.remainingDaylightFormatted
    #expect(formatted.contains("t"))
    #expect(formatted.contains("min"))
}

@Test func solarCalculatorSunriseBeforeSunset() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
    let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12))!

    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let result = SolarCalculator.calculate(for: oslo, date: date)

    #expect(result != nil)
    guard let info = result else { return }
    #expect(info.sunrise < info.sunset)
}
