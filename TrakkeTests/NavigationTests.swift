import Testing
import Foundation
import CoreLocation
@testable import Trakke

// MARK: - Bearing Tests

@Test func bearingNorthward() {
    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let trondheim = CLLocationCoordinate2D(latitude: 63.4305, longitude: 10.3951)
    let bearing = Bearing.bearing(from: oslo, to: trondheim)
    // Oslo to Trondheim is roughly north (~357 degrees)
    #expect(bearing > 350 || bearing < 10)
}

@Test func bearingWestward() {
    let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let bergen = CLLocationCoordinate2D(latitude: 60.3913, longitude: 5.3221)
    let bearing = Bearing.bearing(from: oslo, to: bergen)
    // Oslo to Bergen is roughly west (~283 degrees)
    #expect(bearing > 270 && bearing < 300)
}

@Test func bearingSamePoint() {
    let coord = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    let bearing = Bearing.bearing(from: coord, to: coord)
    // Bearing to same point is indeterminate but should not crash
    #expect(bearing >= 0 && bearing < 360 || bearing.isNaN)
}

@Test func bearingOppositeDirections() {
    let a = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let b = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    let bearingAB = Bearing.bearing(from: a, to: b)
    let bearingBA = Bearing.bearing(from: b, to: a)
    // Samme lengdegrad: sann resiprok peiling avviker < 0,01 grader.
    // Romslig toleranse ville maskert formelregresjoner.
    let diff = abs(bearingAB - bearingBA)
    #expect(abs(diff - 180) < 0.5)
}

// MARK: - NavigationState Model Tests

@Test("NavigationCameraMode raw values")
func cameraModeRawValues() {
    #expect(NavigationCameraMode.northUp.rawValue == "northUp")
    #expect(NavigationCameraMode.courseUp.rawValue == "courseUp")
}

@Test func gpsQualityFromAccuracy() {
    #expect(GPSQuality(accuracy: 5) == .good)
    #expect(GPSQuality(accuracy: 19) == .good)
    #expect(GPSQuality(accuracy: 25) == .reduced)
    #expect(GPSQuality(accuracy: 49) == .reduced)
    #expect(GPSQuality(accuracy: 50) == .lost)
    #expect(GPSQuality(accuracy: 100) == .lost)
    #expect(GPSQuality(accuracy: -1) == .lost)
}

// MARK: - NavigationViewModel Tests

@Test func navigationViewModelStartCompass() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    let isActive = await vm.isActive
    let destination = await vm.destination
    #expect(isActive)
    #expect(destination != nil)
    #expect(abs(destination!.latitude - 60.0) < 0.001)
}

@Test func navigationViewModelStop() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)
    await vm.stopNavigation()

    let isActive = await vm.isActive
    let destination = await vm.destination
    #expect(!isActive)
    #expect(destination == nil)
}

@Test func navigationViewModelToggleCameraMode() async {
    let vm = await NavigationViewModel()
    let initial = await vm.cameraMode
    #expect(initial == .courseUp)

    await vm.toggleCameraMode()
    let toggled = await vm.cameraMode
    #expect(toggled == .northUp)

    await vm.toggleCameraMode()
    let toggledBack = await vm.cameraMode
    #expect(toggledBack == .courseUp)
}

@Test func navigationViewModelCompassUpdate() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 60.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    let location = CLLocation(latitude: 59.5, longitude: 10.0)
    await vm.processLocationUpdate(location)

    let distance = await vm.compassDistance
    let bearing = await vm.compassBearing
    #expect(distance > 50_000) // ~55 km
    #expect(bearing >= 0 && bearing < 360)
}

@Test func navigationViewModelCompassArrival() async throws {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    // Brukeren starter langt fra destinasjonen (>60m).
    let startLocation = CLLocation(latitude: 59.001, longitude: 10.001)
    await vm.processLocationUpdate(startLocation)

    let arrivedAtStart = await vm.hasArrived
    #expect(!arrivedAtStart, "Skal ikke være fremme ved start")

    // `try` (ikke `try?`): blir sleepen kansellert skal testen feile,
    // ikke stille hoppe over oppdateringen som utløser ankomst.
    try await Task.sleep(for: .milliseconds(1100))

    let nearLocation = CLLocation(latitude: 59.00001, longitude: 10.00001)
    await vm.processLocationUpdate(nearLocation)

    let arrived = await vm.hasArrived
    #expect(arrived)
}

@Test func navigationViewModelArrivalFromShortStart() async throws {
    // Start ~50 m fra målet – under minStartDistance (60 m), men ankomst
    // skal likevel fyre når brukeren har nærmet seg mer enn én terskel (30 m).
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    let startLocation = CLLocation(latitude: 59.00045, longitude: 10.0) // ~50 m
    await vm.processLocationUpdate(startLocation)
    let arrivedAtStart = await vm.hasArrived
    #expect(!arrivedAtStart)

    try await Task.sleep(for: .milliseconds(1100))

    let nearLocation = CLLocation(latitude: 59.00004, longitude: 10.0) // ~4 m
    await vm.processLocationUpdate(nearLocation)
    let arrived = await vm.hasArrived
    #expect(arrived, "Ankomst skal fungere også for mål brukeren starter 30-60 m fra")
}

@Test func gpsWatchdogFlagsLostSignalAndRecovers() async throws {
    let vm = await NavigationViewModel()
    await MainActor.run { vm.gpsWatchdogTimeout = 0.2 }
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    try await Task.sleep(for: .milliseconds(600))
    let lostQuality = await vm.gpsQuality
    #expect(lostQuality == .lost, "Uten posisjoner innen timeout skal GPS meldes tapt")

    await vm.processLocationUpdate(CLLocation(latitude: 59.001, longitude: 10.0))
    let recoveredQuality = await vm.gpsQuality
    #expect(recoveredQuality != .lost, "Fersk posisjon skal nullstille vaktbikkja")
}

@Test func navigationViewModelNoFalseArrivalAtStart() async {
    let vm = await NavigationViewModel()
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    await vm.startCompassNavigation(to: dest)

    // Brukeren starter allerede innenfor arrival-terskel.
    let nearStart = CLLocation(latitude: 59.00005, longitude: 10.00005)
    await vm.processLocationUpdate(nearStart)

    let arrived = await vm.hasArrived
    #expect(!arrived, "Skal ikke være fremme ved start når brukeren ikke har beveget seg")
}
