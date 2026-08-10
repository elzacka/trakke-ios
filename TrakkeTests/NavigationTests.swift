import Testing
import Foundation
import CoreLocation
import UIKit
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
    #expect(GPSQuality(accuracy: 9) == .good)
    #expect(GPSQuality(accuracy: 10) == .reduced)
    #expect(GPSQuality(accuracy: 34) == .reduced)
    #expect(GPSQuality(accuracy: 35) == .lost)
    #expect(GPSQuality(accuracy: 100) == .lost)
    #expect(GPSQuality(accuracy: -1) == .lost)
}

// MARK: - Ankomstradius

@Test("Ankomstradius følger GPS-usikkerheten")
func arrivalThresholdScalesWithAccuracy() {
    // God fiks: «Fremme» skal bety at du står ved målet, ikke 30 m unna.
    #expect(NavigationViewModel.arrivalThreshold(for: 4) == 12)
    #expect(NavigationViewModel.arrivalThreshold(for: 12) == 18)
    // Grove fikser får ikke en radius som aldri slår til.
    #expect(NavigationViewModel.arrivalThreshold(for: 45) == 30)
    // CLLocation(latitude:longitude:) rapporterer 0 – da gjelder minimum.
    #expect(NavigationViewModel.arrivalThreshold(for: 0) == 12)
    #expect(NavigationViewModel.arrivalThreshold(for: -1) == 12)
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

/// Bygger en posisjon med kontrollerbar nøyaktighet og alder. Nødvendig for å
/// dekke fiksfilteret: `CLLocation(latitude:longitude:)` gir alltid en fersk
/// fiks med nøyaktighet 0.
private func fix(
    _ latitude: Double,
    _ longitude: Double,
    accuracy: CLLocationAccuracy = 5,
    age: TimeInterval = 0
) -> CLLocation {
    CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        altitude: 0,
        horizontalAccuracy: accuracy,
        verticalAccuracy: -1,
        timestamp: Date().addingTimeInterval(-age)
    )
}

/// Ny ViewModel uten oppdateringsport, slik at tester kan mate inn flere
/// posisjoner etter hverandre uten å sove.
@MainActor
private func makeTestViewModel(destination: CLLocationCoordinate2D) -> NavigationViewModel {
    let vm = NavigationViewModel()
    vm.minUpdateInterval = 0
    vm.startCompassNavigation(to: destination)
    return vm
}

@Test func navigationViewModelCompassArrival() async {
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    // Brukeren starter langt fra destinasjonen.
    await vm.processLocationUpdate(fix(59.001, 10.001))
    let arrivedAtStart = await vm.hasArrived
    #expect(!arrivedAtStart, "Skal ikke være fremme ved start")

    await vm.processLocationUpdate(fix(59.00001, 10.00001))
    await vm.processLocationUpdate(fix(59.00001, 10.00001))

    let arrived = await vm.hasArrived
    #expect(arrived)
}

@Test func navigationViewModelArrivalFromShortStart() async {
    // Start ~50 m fra målet – over én terskel unna, så ankomst skal fyre når
    // brukeren har nærmet seg.
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    await vm.processLocationUpdate(fix(59.00045, 10.0)) // ~50 m
    let arrivedAtStart = await vm.hasArrived
    #expect(!arrivedAtStart)

    await vm.processLocationUpdate(fix(59.00004, 10.0)) // ~4 m
    await vm.processLocationUpdate(fix(59.00004, 10.0))
    let arrived = await vm.hasArrived
    #expect(arrived, "Ankomst skal fungere også for mål brukeren starter 30-60 m fra")
}

@Test("Ankomst krever to påfølgende fikser innenfor radiusen")
func arrivalNeedsConfirmation() async {
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    await vm.processLocationUpdate(fix(59.001, 10.0))       // ~111 m
    await vm.processLocationUpdate(fix(59.00004, 10.0))     // ~4 m
    let afterOne = await vm.hasArrived
    #expect(!afterOne, "Én enkelt fiks skal ikke kunne melde ankomst")

    await vm.processLocationUpdate(fix(59.00004, 10.0))
    let afterTwo = await vm.hasArrived
    #expect(afterTwo)
}

@Test("Grov fiks utløser ikke ankomst")
func arrivalIgnoresImpreciseFix() async {
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    await vm.processLocationUpdate(fix(59.001, 10.0))
    // 80 m usikkerhet: fiksen kan ligge hvor som helst i et kvartal.
    await vm.processLocationUpdate(fix(59.00004, 10.0, accuracy: 80))
    await vm.processLocationUpdate(fix(59.00004, 10.0, accuracy: 80))

    let arrived = await vm.hasArrived
    #expect(!arrived, "Fikser grovere enn 50 m skal ikke brukes til ankomst")
    let quality = await vm.gpsQuality
    #expect(quality == .lost, "Men brukeren skal se at signalet er dårlig")
}

@Test("Hurtigbufret posisjon utløser ikke ankomst")
func arrivalIgnoresStaleFix() async {
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    await vm.processLocationUpdate(fix(59.001, 10.0))
    // Første callback etter start er ofte minutter gammel.
    await vm.processLocationUpdate(fix(59.00004, 10.0, age: 120))
    await vm.processLocationUpdate(fix(59.00004, 10.0, age: 120))

    let arrived = await vm.hasArrived
    #expect(!arrived)
}

@Test("Fremme forsvinner når brukeren går videre")
func arrivalClearsAfterLeaving() async {
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    await vm.processLocationUpdate(fix(59.001, 10.0))
    await vm.processLocationUpdate(fix(59.00004, 10.0))
    await vm.processLocationUpdate(fix(59.00004, 10.0))
    let arrived = await vm.hasArrived
    #expect(arrived)

    // ~56 m unna: godt utenfor radius (12 m) pluss hysterese (15 m).
    await vm.processLocationUpdate(fix(59.0005, 10.0))
    let stillArrived = await vm.hasArrived
    #expect(!stillArrived, "Banneret skal ikke bli stående resten av økten")
}

@Test("Grov fiks blåser ikke opp den observerte maksavstanden")
func maxObservedDistanceIgnoresOutliers() async {
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    // Brukeren står 8 m fra målet hele tiden, men får én villfaren fiks
    // 500 m unna. Uten filteret ville den låst opp ankomst umiddelbart.
    await vm.processLocationUpdate(fix(59.00007, 10.0))
    await vm.processLocationUpdate(fix(59.0045, 10.0, accuracy: 200))
    await vm.processLocationUpdate(fix(59.00007, 10.0))
    await vm.processLocationUpdate(fix(59.00007, 10.0))

    let arrived = await vm.hasArrived
    #expect(!arrived, "Brukeren har ikke beveget seg – ingen ankomst")
}



@Test("Peilingen fryses når avstanden er innenfor GPS-støyen")
func bearingFreezesNearTarget() async {
    let dest = CLLocationCoordinate2D(latitude: 59.0, longitude: 10.0)
    let vm = await makeTestViewModel(destination: dest)

    // 111 m rett sør for målet: peiling 0 grader (nord).
    await vm.processLocationUpdate(fix(58.999, 10.0))
    let farBearing = await vm.compassBearing
    let farReliable = await vm.isBearingReliable
    #expect(abs(farBearing) < 1 || abs(farBearing - 360) < 1)
    #expect(farReliable)

    // 3 m nord for målet: sann peiling er 180 grader, men innenfor støyen.
    await vm.processLocationUpdate(fix(59.000027, 10.0))
    let nearBearing = await vm.compassBearing
    let nearReliable = await vm.isBearingReliable
    #expect(!nearReliable, "Peilingen skal merkes som upålitelig")
    #expect(abs(nearBearing - farBearing) < 1, "og beholde siste stabile verdi")
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

// MARK: - Kameraets følgemodus

@Test("Følgemodus utledes fra kartets faktiske tilstand")
func cameraFollowModeDerivation() {
    // Ved oppstart følger kartet ingenting – knappen skal ikke påstå noe annet.
    #expect(MapCameraFollowMode.current(
        isCameraDetached: false, isNavigating: false,
        navigationCameraMode: .northUp, isTrackingUser: false, isHeadingUp: false
    ) == .free)

    // Sporing på, nord opp.
    #expect(MapCameraFollowMode.current(
        isCameraDetached: false, isNavigating: false,
        navigationCameraMode: .northUp, isTrackingUser: true, isHeadingUp: false
    ) == .followNorth)

    #expect(MapCameraFollowMode.current(
        isCameraDetached: false, isNavigating: false,
        navigationCameraMode: .northUp, isTrackingUser: true, isHeadingUp: true
    ) == .followHeading)

    // Under navigasjon eier navigasjonen kameramodusen.
    #expect(MapCameraFollowMode.current(
        isCameraDetached: false, isNavigating: true,
        navigationCameraMode: .courseUp, isTrackingUser: true, isHeadingUp: false
    ) == .followHeading)

    #expect(MapCameraFollowMode.current(
        isCameraDetached: false, isNavigating: true,
        navigationCameraMode: .northUp, isTrackingUser: true, isHeadingUp: true
    ) == .followNorth)

    // Frakobling slår alt annet – også midt i navigasjon.
    #expect(MapCameraFollowMode.current(
        isCameraDetached: true, isNavigating: true,
        navigationCameraMode: .courseUp, isTrackingUser: true, isHeadingUp: true
    ) == .free)
}

@Test("Hver modus har sitt eget ikon, og ikonene finnes")
func cameraFollowModeSymbols() {
    let modes: [MapCameraFollowMode] = [.free, .followNorth, .followHeading]
    let names = modes.map(\.symbolName)

    // Formen må skille modusene – farge alene bryter WCAG 1.4.1.
    #expect(Set(names).count == 3, "Modusene skal ikke dele ikon")

    // Et feilskrevet SF Symbol-navn renderer som ingenting uten å feile.
    for name in names {
        #expect(UIImage(systemName: name) != nil, "Ukjent SF Symbol: \(name)")
    }
}

@Test("Alle modusnavn er oversatt")
func cameraFollowModeNames() {
    for mode in [MapCameraFollowMode.free, .followNorth, .followHeading] {
        let name = mode.localizedName
        #expect(!name.isEmpty)
        // En manglende nøkkel gir nøkkelen tilbake som tekst.
        #expect(!name.hasPrefix("map.camera."), "Uoversatt nøkkel: \(name)")
    }
}
