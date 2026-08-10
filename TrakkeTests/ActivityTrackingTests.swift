import Testing
import Foundation
import CoreLocation
@testable import Trakke

// MARK: - ActivityTrackingService Tests

@Test func activityTrackingRejectsLowAccuracyPoints() async {
    let service = ActivityTrackingService()
    await service.start()

    // Accuracy > 50m should be rejected
    let badLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 100,
        verticalAccuracy: 10,
        timestamp: Date()
    )
    await service.addLocation(badLocation)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 0)
}

@Test func activityTrackingRejectsNegativeAccuracy() async {
    let service = ActivityTrackingService()
    await service.start()

    let badLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: -1,
        verticalAccuracy: 10,
        timestamp: Date()
    )
    await service.addLocation(badLocation)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 0)
}

@Test func activityTrackingAcceptsGoodAccuracy() async {
    let service = ActivityTrackingService()
    await service.start()

    let goodLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 10,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(goodLocation)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 1)
}

/// Et punkt som verken har flyttet seg nok eller ventet lenge nok, lagres ikke.
@Test func activityTrackingSkipsPointThatNeitherMovedNorWaited() async {
    let service = ActivityTrackingService()
    await service.start()
    let start = Date()

    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: start
    )
    await service.addLocation(loc1)

    // ~1 m unna og bare 1 sekund senere: under begge tersklene.
    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.900009, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: start.addingTimeInterval(1)
    )
    await service.addLocation(loc2)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 1)
    #expect(stats.distance == 0)
}

/// Uavhengige Task-hopp kan levere GPS-fikser i feil rekkefølge. Et punkt
/// eldre enn det siste lagrede skal forkastes – ellers får sporet
/// tidsstempler som går baklengs, og distansen teller et fantomsteg.
@Test func activityTrackingDropsOutOfOrderFix() async {
    let service = ActivityTrackingService()
    await service.start()
    let start = Date()

    let newer = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: start.addingTimeInterval(30)
    )
    await service.addLocation(newer)

    // Fiksen fra før den forrige, levert for sent.
    let older = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.902, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: start
    )
    await service.addLocation(older)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 1)
    #expect(stats.distance == 0)
}

/// Står du stille, skal oppholdet likevel havne i sporet – det er dét som
/// gjør pauser synlige i ettertid. Men det skal ikke legge til distanse.
@Test func activityTrackingRecordsStandingStillWithoutAddingDistance() async {
    let service = ActivityTrackingService()
    await service.start()
    let start = Date()

    for second in stride(from: 0, through: 30, by: 6) {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(Double(second))
        )
        await service.addLocation(location)
    }

    let stats = await service.currentStats()
    #expect(stats.pointCount == 6)
    #expect(stats.distance == 0)
}

/// GPS-støy i hvile skal ikke blåse opp distansen selv om punktene lagres.
/// Ankeret flyttes først når steget er stort nok til å være bevegelse.
@Test func activityTrackingNoiseWhileStationaryDoesNotAddDistance() async {
    let service = ActivityTrackingService()
    await service.start()
    let start = Date()
    // Drift fram og tilbake på et par meter, langt under distanseterskelen.
    let offsets: [Double] = [0, 0.000025, -0.000025, 0.00002, -0.00002, 0]

    for (index, offset) in offsets.enumerated() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.9 + offset, longitude: 10.7),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(Double(index) * 6)
        )
        await service.addLocation(location)
    }

    let stats = await service.currentStats()
    #expect(stats.pointCount == offsets.count)
    #expect(stats.distance == 0)
}

@Test func activityTrackingDistanceAccumulates() async {
    let service = ActivityTrackingService()
    await service.start()

    // Two points ~111m apart (0.001 degrees latitude)
    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(30)
    )
    await service.addLocation(loc2)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 2)
    #expect(stats.distance > 50)
    #expect(stats.distance < 200)
}

@Test func activityTrackingElevationThreshold() async {
    let service = ActivityTrackingService()
    await service.start()

    // Point 1: 100m altitude
    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    // Point 2: 102m altitude (only +2m, below 3m threshold – should NOT count)
    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
        altitude: 102,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(30)
    )
    await service.addLocation(loc2)

    let stats2 = await service.currentStats()
    #expect(stats2.elevationGain == 0)

    // Point 3: 110m altitude (+8m from point 2, above threshold)
    let loc3 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.902, longitude: 10.7),
        altitude: 110,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(60)
    )
    await service.addLocation(loc3)

    let stats3 = await service.currentStats()
    #expect(stats3.elevationGain > 0)
}

@Test func activityTrackingElevationLoss() async {
    let service = ActivityTrackingService()
    await service.start()

    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 200,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    // Drop 20m
    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
        altitude: 180,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(30)
    )
    await service.addLocation(loc2)

    let stats = await service.currentStats()
    #expect(stats.elevationLoss > 0)
    #expect(stats.elevationGain == 0)
}

@Test func activityFinishAggregates() async {
    let service = ActivityTrackingService()
    await service.start()

    let loc1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(loc1)

    let loc2 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.902, longitude: 10.7),
        altitude: 150,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(120)
    )
    await service.addLocation(loc2)

    let result = await service.finish()
    #expect(result.trackPoints.count == 2)
    #expect(result.distance > 100)
    #expect(result.elevationGain > 0)
    #expect(result.duration > 0)
    #expect(result.startedAt < result.endedAt)

    // [lon, lat, alt, timestamp, hAcc, speed, course, vAcc]
    #expect(result.trackPoints[0].count == 8)
}

/// Etter `finish()` er økta over. En GPS-fiks som fortsatt var underveis da
/// brukeren stoppet, skal verken lagres eller utløse et sjekkpunkt – den
/// kunne ellers skrive en forkastet tur tilbake til disk.
@Test func activityAddLocationAfterFinishIsDropped() async {
    let service = ActivityTrackingService()
    await service.start()

    let location = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date()
    )
    await service.addLocation(location)
    _ = await service.finish()

    let straggler = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 5,
        verticalAccuracy: 5,
        timestamp: Date().addingTimeInterval(30)
    )
    await service.addLocation(straggler)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 1)
}

// MARK: - Sporpunktenes innhold

/// De fire første tallene skal ligge der de alltid har ligget. Endres
/// rekkefølgen, leses gamle turer feil uten at noe kompilerer galt.
@Test func trackPointLayoutIsAdditive() async {
    let service = ActivityTrackingService()
    await service.start()
    let timestamp = Date()

    let location = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 100,
        horizontalAccuracy: 7,
        verticalAccuracy: 4,
        course: 90,
        speed: 1.5,
        timestamp: timestamp
    )
    await service.addLocation(location)

    let point = await service.finish().trackPoints[0]
    #expect(point[0] == 10.7)
    #expect(point[1] == 59.9)
    #expect(point[2] == 100)
    #expect(abs(point[3] - timestamp.timeIntervalSince1970) < 0.001)
    #expect(Activity.horizontalAccuracy(of: point) == 7)
    #expect(Activity.speed(of: point) == 1.5)
    #expect(Activity.course(of: point) == 90)
}

/// CoreLocation bruker negative tall for «vet ikke». De skal aldri komme ut
/// som om de var målinger.
@Test func unmeasuredValuesAreNilNotNegative() async {
    let service = ActivityTrackingService()
    await service.start()

    let location = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
        altitude: 0,
        horizontalAccuracy: 5,
        verticalAccuracy: -1,
        course: -1,
        speed: -1,
        timestamp: Date()
    )
    await service.addLocation(location)

    let point = await service.finish().trackPoints[0]
    #expect(Activity.speed(of: point) == nil)
    #expect(Activity.course(of: point) == nil)
    #expect(Activity.altitude(of: point) == nil)
}

/// Null meter over havet er en gyldig måling langs kysten, ikke manglende
/// data. Skillet ligger i `verticalAccuracy`.
@Test func measuredSeaLevelIsNotTreatedAsMissing() async {
    let service = ActivityTrackingService()
    await service.start()

    let location = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 58.9, longitude: 5.7),
        altitude: 0,
        horizontalAccuracy: 5,
        verticalAccuracy: 3,
        timestamp: Date()
    )
    await service.addLocation(location)

    let point = await service.finish().trackPoints[0]
    #expect(Activity.altitude(of: point) == 0)
}

/// Turer tatt opp før nøyaktighetsfeltene fantes har fire tall per punkt.
/// De skal fortsatt leses, ikke krasje eller gi tilfeldige verdier.
@Test @MainActor func legacyFourValueTrackPointsStillRead() {
    let legacy: [Double] = [10.7, 59.9, 250, Date().timeIntervalSince1970]
    #expect(Activity.altitude(of: legacy) == 250)
    #expect(Activity.horizontalAccuracy(of: legacy) == nil)
    #expect(Activity.speed(of: legacy) == nil)
    #expect(Activity.course(of: legacy) == nil)
}

// MARK: - Avledet statistikk

@Test @MainActor func movingDurationIgnoresGapsInTheTrack() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Med hull")
    // To steg på 30 sekunder hver, og ett hull på en time midt i.
    activity.trackPoints = [
        [10.7000, 59.9000, 100, start, 5, 1.2, 0, 3],
        [10.7000, 59.9005, 100, start + 30, 5, 1.2, 0, 3],
        [10.7000, 59.9200, 100, start + 3630, 5, 1.2, 0, 3],
        [10.7000, 59.9205, 100, start + 3660, 5, 1.2, 0, 3]
    ]
    #expect(activity.movingDuration == 60)
}

@Test @MainActor func movingDurationIgnoresStandingStill() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Med pause")
    activity.trackPoints = [
        [10.7000, 59.9000, 100, start, 5, 1.2, 0, 3],
        // Ti minutter uten forflytning: pause, ikke bevegelse.
        [10.7000, 59.9000, 100, start + 600, 5, 0, 0, 3],
        [10.7000, 59.9005, 100, start + 630, 5, 1.2, 0, 3]
    ]
    #expect(activity.movingDuration == 30)
}

@Test @MainActor func altitudeExtremesSkipUnmeasuredPoints() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Delvis høyde")
    activity.trackPoints = [
        [10.7, 59.9000, 300, start, 5, 1, 0, 3],
        // Umålt høyde, lagret som 0. Skal ikke bli laveste punkt.
        [10.7, 59.9005, 0, start + 30, 5, 1, 0, -1],
        [10.7, 59.9010, 420, start + 60, 5, 1, 0, 3]
    ]
    #expect(activity.minAltitude == 300)
    #expect(activity.maxAltitude == 420)
}

@Test @MainActor func maxSpeedIgnoresUnmeasuredSpeed() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Fart")
    activity.trackPoints = [
        [10.7, 59.9000, 100, start, 5, -1, -1, 3],
        [10.7, 59.9005, 100, start + 30, 5, 2.4, 0, 3]
    ]
    #expect(activity.maxSpeed == 2.4)
}

// MARK: - ActivityViewModel Formatting Tests

@Test @MainActor func formatDurationMinutesOnly() {
    let result = ActivityViewModel.formatDuration(125) // 2:05
    #expect(result == "2:05")
}

@Test @MainActor func formatDurationWithHours() {
    let result = ActivityViewModel.formatDuration(3725) // 1:02:05
    #expect(result == "1:02:05")
}

@Test @MainActor func formatDurationZero() {
    let result = ActivityViewModel.formatDuration(0)
    #expect(result == "0:00")
}

// MARK: - GPX-eksport av spor

@Test @MainActor func gpxCarriesMeasuredSpeedCourseAndAccuracy() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Med utvidelser")
    activity.trackPoints = [[10.7, 59.9, 320, start, 6.5, 1.75, 91.5, 3]]

    let gpx = GPXExportService.exportActivity(activity)
    #expect(gpx.contains("xmlns:gpxtpx="))
    #expect(gpx.contains("<gpxtpx:TrackPointExtension>"))
    #expect(gpx.contains("<gpxtpx:speed>1.75</gpxtpx:speed>"))
    #expect(gpx.contains("<gpxtpx:course>91.5</gpxtpx:course>"))
    #expect(gpx.contains("<trakke:hdop>6.5</trakke:hdop>"))
    #expect(gpx.contains("<ele>320.0</ele>"))
}

/// Et umålt felt skal mangle i fila, ikke stå der med en oppdiktet verdi.
@Test @MainActor func gpxOmitsUnmeasuredValues() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Uten utvidelser")
    activity.trackPoints = [[10.7, 59.9, 0, start, 5, -1, -1, -1]]

    let gpx = GPXExportService.exportActivity(activity)
    #expect(!gpx.contains("gpxtpx:speed"))
    #expect(!gpx.contains("gpxtpx:course"))
    #expect(!gpx.contains("<ele>"))
    // Sentinelen skal ikke stå som en verdi. Sjekken var tidligere
    // `!gpx.contains("-1")`, som også traff datoen i `<time>`: enhver dag fra
    // den 10. til den 19., og hele oktober til desember, gir «-1» i
    // ISO-datoen og en rød test uten at noe er galt med eksporten.
    #expect(!gpx.contains(">-1"))
    #expect(gpx.contains("<trakke:hdop>5.0</trakke:hdop>"))
}

/// Koordinater skrives med fast presisjon. Uten det lekker flyttallsstøy som
/// `61.49150000000001` ut i fila og gir falsk nøyaktighet.
@Test @MainActor func gpxCoordinatesUseFixedPrecision() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Presisjon")
    activity.trackPoints = [[8.6295000000001, 61.4915000000001, 100, start, 5, 1, 0, 3]]

    let gpx = GPXExportService.exportActivity(activity)
    #expect(gpx.contains("lat=\"61.4915000\""))
    #expect(gpx.contains("lon=\"8.6295000\""))
}

/// Turer tatt opp av eldre versjoner har fire tall per punkt og skal
/// eksporteres uendret, uten utvidelser.
@Test @MainActor func gpxHandlesLegacyTrackPoints() {
    let start = Date().timeIntervalSince1970
    let activity = Activity(name: "Gammel tur")
    activity.trackPoints = [[10.7, 59.9, 250, start]]

    let gpx = GPXExportService.exportActivity(activity)
    #expect(gpx.contains("<ele>250.0</ele>"))
    #expect(!gpx.contains("<extensions>"))
}

// MARK: - Avbrutt opptak

/// Et opptak som ble avbrutt skal kunne tas opp igjen med sporet i behold,
/// og statistikken skal bli den samme som om det aldri hadde stoppet.
@Test func resumingRecoversTrackAndStatistics() async {
    let start = Date()
    let reference = ActivityTrackingService()
    await reference.start()
    for step in 0..<6 {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.9 + Double(step) * 0.001, longitude: 10.7),
            altitude: 100 + Double(step) * 10,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(Double(step) * 30)
        )
        await reference.addLocation(location, relativeAltitude: nil)
    }
    let expected = await reference.finish()

    // Samme spor, men levert gjennom en journal etter et avbrudd.
    let resumed = ActivityTrackingService()
    await resumed.resume(
        from: ActivityRecordingJournal(startedAt: start, trackPoints: expected.trackPoints)
    )
    let stats = await resumed.currentStats()

    #expect(stats.pointCount == expected.trackPoints.count)
    #expect(abs(stats.distance - expected.distance) < 0.001)
    #expect(abs(stats.elevationGain - expected.elevationGain) < 0.001)
    #expect(abs(stats.elevationLoss - expected.elevationLoss) < 0.001)
}

/// En journal med søppelrader skal ikke ta med seg hele opptaket i fallet.
@Test func resumingSkipsUnusableRows() async {
    let start = Date()
    let journal = ActivityRecordingJournal(
        startedAt: start,
        trackPoints: [
            [10.7, 59.9, 100, start.timeIntervalSince1970],
            [.nan, 59.9, 100, start.timeIntervalSince1970 + 30],   // ugyldig lengdegrad
            [10.7, 200, 100, start.timeIntervalSince1970 + 60],    // breddegrad utenfor jorda
            [10.7],                                                // for kort rad
            [10.7, 59.901, 100, start.timeIntervalSince1970 + 90]
        ]
    )
    let service = ActivityTrackingService()
    await service.resume(from: journal)

    let stats = await service.currentStats()
    #expect(stats.pointCount == 2)
}

// MARK: - Journalformatet

/// Journalen skrives som JSON Lines: hodet med starttidspunktet på første
/// linje, deretter ett punkt per linje.
@Test func journalDecodesLineFormat() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let encoder = JSONEncoder()
    var data = try encoder.encode(ActivityRecordingJournal(startedAt: start, trackPoints: []))
    data.append(Data("\n".utf8))
    data.append(try encoder.encode([10.7, 59.9, 100.0, start.timeIntervalSince1970]))
    data.append(Data("\n".utf8))
    data.append(try encoder.encode([10.701, 59.901, 110.0, start.timeIntervalSince1970 + 30]))
    data.append(Data("\n".utf8))

    let journal = try #require(ActivityRecordingJournal.decode(data))
    #expect(abs(journal.startedAt.timeIntervalSince(start)) < 0.001)
    #expect(journal.trackPoints.count == 2)
    #expect(journal.trackPoints[0][0] == 10.7)
    #expect(journal.trackPoints[1][2] == 110.0)
}

/// En journal fra en eldre versjon er hele dokumentet som ett JSON-objekt.
/// Den skal fortsatt leses etter en oppdatering midt i et avbrutt opptak –
/// en journal som stille ble forkastet, ville vært en tapt tur.
@Test func journalDecodesLegacyWholeFileFormat() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let legacy = ActivityRecordingJournal(
        startedAt: start,
        trackPoints: [
            [10.7, 59.9, 100, start.timeIntervalSince1970],
            [10.701, 59.901, 110, start.timeIntervalSince1970 + 30]
        ]
    )
    let data = try JSONEncoder().encode(legacy)

    let journal = try #require(ActivityRecordingJournal.decode(data))
    #expect(abs(journal.startedAt.timeIntervalSince(start)) < 0.001)
    #expect(journal.trackPoints.count == 2)
}

/// Dør appen midt i en skriving, er siste linje avrevet. Den skal forkastes
/// uten å ta med seg punktene som allerede står trygt.
@Test func journalDropsTornFinalLine() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let encoder = JSONEncoder()
    var data = try encoder.encode(ActivityRecordingJournal(startedAt: start, trackPoints: []))
    data.append(Data("\n".utf8))
    data.append(try encoder.encode([10.7, 59.9, 100.0, start.timeIntervalSince1970]))
    data.append(Data("\n".utf8))
    data.append(Data("[10.701,59.9".utf8)) // avrevet midt i en skriving

    let journal = try #require(ActivityRecordingJournal.decode(data))
    #expect(journal.trackPoints.count == 1)
    #expect(journal.trackPoints[0][1] == 59.9)
}

/// Et avrevet fragment kan stå *midt* i fila: strømbrudd midt i en skriving,
/// gjenoppretting, og neste sjekkpunkt skriver nye punkter bak fragmentet.
/// Punktene etter fragmentet skal overleve — stopp-på-første-feil ville
/// stille forkastet timevis av tur.
@Test func journalSkipsTornMiddleLine() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let encoder = JSONEncoder()
    var data = try encoder.encode(ActivityRecordingJournal(startedAt: start, trackPoints: []))
    data.append(Data("\n".utf8))
    data.append(try encoder.encode([10.7, 59.9, 100.0, start.timeIntervalSince1970]))
    data.append(Data("\n".utf8))
    data.append(Data("[10.701,59.9\n".utf8)) // avrevet ved strømbrudd, nå midt i fila
    data.append(try encoder.encode([10.702, 59.901, 101.0, start.timeIntervalSince1970 + 10]))
    data.append(Data("\n".utf8))

    let journal = try #require(ActivityRecordingJournal.decode(data))
    #expect(journal.trackPoints.count == 2)
    #expect(journal.trackPoints[1][0] == 10.702)
}

/// Barometeret og GPS har ulike nullpunkt. Blandes de i samme tur blir
/// høydemeterne meningsløse, så kilden skal låses ved første målte punkt.
@Test func elevationSourceDoesNotMixBarometerAndGPS() async {
    let start = Date()
    let service = ActivityTrackingService()
    await service.start()

    // Første punkt har barometer: kilden låses der.
    await service.addLocation(
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
            altitude: 1000,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start
        ),
        relativeAltitude: 0
    )
    // Punkt uten barometermåling skal ikke bidra, selv om GPS-høyden spratt.
    await service.addLocation(
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.901, longitude: 10.7),
            altitude: 1400,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(30)
        ),
        relativeAltitude: nil
    )
    let afterGap = await service.currentStats()
    #expect(afterGap.elevationGain == 0)

    // Barometeret er tilbake og har steget 50 m.
    await service.addLocation(
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.902, longitude: 10.7),
            altitude: 1400,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(60)
        ),
        relativeAltitude: 50
    )
    let final = await service.currentStats()
    #expect(abs(final.elevationGain - 50) < 0.001)
}

/// Barometrisk høyde legges bare til raden når den finnes. Lengden på raden
/// er signalet – ingen sentinelverdi som kan forveksles med en måling.
@Test func barometricAltitudeOnlyAppearsWhenMeasured() async {
    let service = ActivityTrackingService()
    await service.start()

    await service.addLocation(
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        ),
        relativeAltitude: nil
    )
    let withoutBarometer = await service.finish()
    #expect(withoutBarometer.trackPoints[0].count == 8)

    let withBarometerService = ActivityTrackingService()
    await withBarometerService.start()
    await withBarometerService.addLocation(
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 59.9, longitude: 10.7),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        ),
        relativeAltitude: 12.5
    )
    let withBarometer = await withBarometerService.finish()
    #expect(withBarometer.trackPoints[0].count == 9)
    #expect(withBarometer.trackPoints[0][8] == 12.5)
}

// MARK: - Høydemeter, én kilde

/// Terskelen skal fjerne målestøy, ikke ekte terreng.
@Test func elevationIgnoresNoiseBelowThreshold() {
    // Vingling på ±2 m rundt samme høyde: ingen høydemeter.
    let noisy: [Double?] = [1000, 1002, 999, 1001, 998, 1000]
    let noise = ElevationMath.gainLoss(altitudes: noisy)
    #expect(noise.gain == 0)
    #expect(noise.loss == 0)

    // Ekte stigning på 40 m telles.
    let climb: [Double?] = [1000, 1010, 1020, 1030, 1040]
    let real = ElevationMath.gainLoss(altitudes: climb)
    #expect(abs(real.gain - 40) < 0.001)
    #expect(real.loss == 0)
}

/// Et hull i høydedataene skal ikke koste høydemeterne rundt hullet.
@Test func elevationSkipsGapsWithoutBreakingTheChain() {
    let withGap: [Double?] = [1000, nil, nil, 1050, nil, 1020]
    let result = ElevationMath.gainLoss(altitudes: withGap)
    #expect(abs(result.gain - 50) < 0.001)
    #expect(abs(result.loss - 30) < 0.001)
}

/// Samme trasé skal gi samme høydemeter enten den ligger som rute eller som
/// tur. Det var ikke tilfelle før: ruter summerte hver minste endring.
@Test @MainActor func routeAndActivityAgreeOnElevation() {
    // Stigende terreng med et par meter støy på hvert punkt.
    var coordinates: [[Double]] = []
    var trackPoints: [[Double]] = []
    let start = Date().timeIntervalSince1970
    for step in 0..<200 {
        let base = 1000.0 + Double(step) * 2.0
        let noise = (step % 3 == 0) ? 1.5 : -1.5
        let altitude = base + noise
        let longitude = 8.6 + Double(step) * 0.0002
        coordinates.append([longitude, 61.5, altitude])
        trackPoints.append([longitude, 61.5, altitude, start + Double(step) * 10, 5, 1, 0, 3])
    }

    let route = try? #require(RouteViewModel.elevationGainLoss(forCoordinates: coordinates))
    let activity = Activity(name: "Samme trasé")
    activity.trackPoints = trackPoints
    let viaActivity = ElevationMath.gainLoss(altitudes: trackPoints.map(Activity.altitude))

    #expect(route?.gain == viaActivity.gain)
    #expect(route?.loss == viaActivity.loss)
}

/// Ruter med høyde på noen, men ikke alle, punkter ga før ingen høydemeter i
/// det hele tatt.
@Test @MainActor func routeElevationWorksWithPartialData() {
    let coordinates: [[Double]] = [
        [8.60, 61.5, 1000],
        [8.61, 61.5],          // uten høyde
        [8.62, 61.5, 1080],
        [8.63, 61.5]           // uten høyde
    ]
    let result = RouteViewModel.elevationGainLoss(forCoordinates: coordinates)
    #expect(result?.gain == 80)
}

/// Under to målte punkter finnes det ingen høydeendring å rapportere.
@Test @MainActor func routeElevationNilWithoutEnoughData() {
    #expect(RouteViewModel.elevationGainLoss(forCoordinates: [[8.6, 61.5, 1000]]) == nil)
    #expect(RouteViewModel.elevationGainLoss(forCoordinates: [[8.6, 61.5], [8.61, 61.5]]) == nil)
}
