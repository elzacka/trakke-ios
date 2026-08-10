import Foundation
import CoreLocation

struct TrackPoint: Sendable {
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    /// Meter per sekund. Negativ når CoreLocation ikke har et gyldig mål.
    let speed: Double
    /// Kurs i grader fra nord. Negativ når CoreLocation ikke har et gyldig mål.
    let course: Double
    /// Negativ når høyden ikke er målt. Uten dette feltet er en høyde på 0
    /// tvetydig: appen har alltid skrevet 0 for «vet ikke», men 0 meter over
    /// havet er også en helt gyldig måling langs norskekysten.
    let verticalAccuracy: Double
    /// Barometrisk høyde, relativt til der opptaket startet. `nil` når enheten
    /// mangler barometer eller brukeren ikke har gitt tilgang til bevegelse.
    let relativeAltitude: Double?
}

protocol ActivityTracking: Sendable {
    func start() async
    func resume(from journal: ActivityRecordingJournal) async
    func addLocation(_ location: CLLocation, relativeAltitude: Double?) async
    func checkpointNow() async
    func finish() async -> ActivityResult
    func currentStats() async -> ActivityStats
}

/// Sporet lagres tett, statistikken regnes grovt.
///
/// Tidligere ble et punkt bare tatt vare på når det lå minst 10 m fra forrige,
/// og terskelen styrte både hva som ble lagret og hva som ble summert. Det ga
/// riktige totaler, men et spor uten oppløsning: pauser forsvant, bratte
/// sikksakk ble rette streker, og fart kunne aldri regnes ut i ettertid.
/// Punkter som aldri ble lagret, kan ikke hentes tilbake.
///
/// Nå er de to tingene skilt. Punkter lagres tett – ved bevegelse over
/// `minRecordDistance`, eller etter `minRecordInterval` selv om du står stille,
/// slik at et opphold ligger i sporet som det det er. Distanse og høydemeter
/// summeres fortsatt mot et *anker* som bare flyttes når bevegelsen er stor
/// nok. Tallene blir dermed de samme som før, uten at GPS-støy i hvile blåser
/// dem opp.
actor ActivityTrackingService: ActivityTracking {
    private var trackPoints: [TrackPoint] = []
    private var startTime: Date?
    private var totalDistance: Double = 0
    private var elevationGain: Double = 0
    private var elevationLoss: Double = 0

    /// Ankeret distanse måles fra. Flyttes først når steget er stort nok til
    /// å være bevegelse og ikke støy.
    private var distanceAnchor: CLLocationCoordinate2D?
    /// Tilsvarende anker for høyde.
    private var elevationAnchor: Double?

    /// Hvilken høydekilde turen bruker. Låses ved første målte punkt og
    /// blandes aldri – to kilder med ulikt nullpunkt gir en meningsløs sum.
    private enum ElevationSource {
        case undecided
        case barometer
        case satellite
    }
    private var elevationSource: ElevationSource = .undecided

    /// Dårligste horisontale nøyaktighet et punkt kan ha og fortsatt lagres (meter).
    private static let maxAccuracy: Double = 50
    /// Minste bevegelse før et nytt punkt lagres (meter).
    private static let minRecordDistance: Double = 2
    /// Lagre et punkt uansett når det har gått så lenge siden forrige (sekunder).
    /// Det er dette som gjør pauser synlige i sporet.
    private static let minRecordInterval: TimeInterval = 5
    /// Minste steg som telles som tilbakelagt distanse (meter).
    private static let distanceThreshold: Double = 10
    /// Minste høydeendring som telles som stigning eller fall (meter).
    /// Opptaket summerer løpende og kan ikke bruke `ElevationMath.gainLoss`
    /// direkte, men terskelen skal være den samme – ellers gir en tur andre
    /// tall enn den samme turen gjør etter en eksport og import.
    private static let elevationThreshold = ElevationMath.threshold

    /// Hvor mange punkter som kan gå tapt hvis appen dør mellom to
    /// sjekkpunkter. Ved 5 sekunders lagringsintervall er ti punkter under et
    /// minutt av turen.
    private static let checkpointInterval = 10
    /// Hvor mange av punktene i `trackPoints` som allerede står i journalen.
    /// Rykker bare fram når en skriving faktisk lyktes – feiler den, tar
    /// neste sjekkpunkt med seg den samme halen på nytt.
    private var journaledCount = 0

    func start() {
        trackPoints = []
        totalDistance = 0
        elevationGain = 0
        elevationLoss = 0
        distanceAnchor = nil
        elevationAnchor = nil
        elevationSource = .undecided
        journaledCount = 0
        startTime = Date()
        ActivityRecordingJournal.clear()
    }

    /// Gjenopptar et opptak som ble avbrutt av at appen døde. Statistikken
    /// regnes på nytt fra punktene i stedet for å bli lagret i journalen –
    /// da kan tallene aldri komme i utakt med sporet de skal beskrive.
    func resume(from journal: ActivityRecordingJournal) {
        trackPoints = journal.trackPoints.compactMap(Self.decode)
        startTime = journal.startedAt
        // Punktene fra journalen ligger allerede på disk. Uten dette ville
        // første sjekkpunkt etter gjenopptak skrevet hele det gjenopprettede
        // sporet til journalen en gang til.
        journaledCount = trackPoints.count

        totalDistance = 0
        elevationGain = 0
        elevationLoss = 0
        distanceAnchor = nil
        elevationAnchor = nil
        elevationSource = .undecided
        for point in trackPoints {
            accumulateDistance(to: point)
            accumulateElevation(to: point)
        }
    }

    func addLocation(_ location: CLLocation) {
        addLocation(location, relativeAltitude: nil)
    }

    /// `relativeAltitude` kommer fra `BarometerService` og sendes inn i stedet
    /// for å leses her, så denne aktøren slipper å kjenne CoreMotion – og lar
    /// seg teste uten en sensor.
    func addLocation(_ location: CLLocation, relativeAltitude: Double?) {
        // Økta er over etter `finish()`. En fiks som fortsatt var underveis
        // da brukeren stoppet, skal verken lagres eller utløse et sjekkpunkt
        // – den kunne ellers skrive en forkastet tur tilbake til disk.
        guard startTime != nil else { return }
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= Self.maxAccuracy,
              location.coordinate.latitude.isFinite,
              location.coordinate.longitude.isFinite else {
            return
        }

        // Høyden skrives fortsatt som 0 når den ikke er målt, slik den alltid
        // har blitt – eldre lesere av sporet regner med det. Tvetydigheten
        // ryddes opp av `verticalAccuracy` ved siden av, ikke ved å endre
        // betydningen av et felt som allerede ligger lagret hos folk.
        let point = TrackPoint(
            coordinate: location.coordinate,
            altitude: location.verticalAccuracy >= 0 ? location.altitude : 0,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            course: location.course,
            verticalAccuracy: location.verticalAccuracy,
            relativeAltitude: relativeAltitude
        )

        if let lastPoint = trackPoints.last {
            // Uavhengige Task-hopp kan levere fikser om hverandre; et punkt eldre
            // enn det siste lagrede er alltid feil rekkefølge eller duplikat.
            guard point.timestamp > lastPoint.timestamp else { return }
            let movedFar = Haversine.distance(from: lastPoint.coordinate, to: point.coordinate)
                >= Self.minRecordDistance
            let waitedLong = point.timestamp.timeIntervalSince(lastPoint.timestamp)
                >= Self.minRecordInterval
            guard movedFar || waitedLong else { return }
        }

        accumulateDistance(to: point)
        accumulateElevation(to: point)
        trackPoints.append(point)

        if trackPoints.count - journaledCount >= Self.checkpointInterval {
            checkpoint()
        }
    }

    /// Skriver punktene som ennå ikke står i journalen, til disk, så sporet
    /// overlever at appen blir avlivet. Bare halen legges til – å skrive hele
    /// den voksende fila på nytt hvert tiende punkt summerte seg til hundrevis
    /// av megabyte flash-skriving på en lang tur. `journaledCount` rykker
    /// først fram når skrivingen lyktes; feiler den, prøves samme hale igjen.
    private func checkpoint() {
        guard let startTime else { return }
        guard journaledCount < trackPoints.count else { return }
        let tail = trackPoints[journaledCount...].map(Self.encode)
        if ActivityRecordingJournal.append(points: tail, startedAt: startTime) {
            journaledCount = trackPoints.count
        }
    }

    /// Distansen summeres mot ankeret, ikke mot forrige lagrede punkt. Uten
    /// det ville tett lagring gjort at GPS-støyen i hvile ble lagt til turen.
    private func accumulateDistance(to point: TrackPoint) {
        guard let anchor = distanceAnchor else {
            distanceAnchor = point.coordinate
            return
        }
        let dist = Haversine.distance(from: anchor, to: point.coordinate)
        guard dist >= Self.distanceThreshold else { return }
        totalDistance += dist
        distanceAnchor = point.coordinate
    }

    /// Høydemeter regnes fra barometeret når det finnes, ellers fra GPS.
    ///
    /// Barometeret måler endring langt mer presist enn GPS – som typisk bommer
    /// ti til tjue meter, og mer under bratte sider – og høydemeter er summen
    /// av endringer. Det virker dessuten uten satellittsignal.
    ///
    /// Blandes de to i samme tur, blir summen tull: verdiene har ulike
    /// nullpunkt og ulik støy. Derfor låses kilden til den som fantes ved
    /// første målte punkt, og holdes gjennom hele opptaket.
    private func accumulateElevation(to point: TrackPoint) {
        let value: Double
        switch elevationSource {
        case .undecided:
            if let barometric = point.relativeAltitude {
                elevationSource = .barometer
                elevationAnchor = barometric
            } else if point.verticalAccuracy >= 0 {
                elevationSource = .satellite
                elevationAnchor = point.altitude
            }
            return
        case .barometer:
            guard let barometric = point.relativeAltitude else { return }
            value = barometric
        case .satellite:
            // Bare målte høyder. Tidligere var testen `altitude > 0`, som både
            // slapp inn umålte punkter langs kysten og kastet ekte målinger
            // ved havnivå.
            guard point.verticalAccuracy >= 0 else { return }
            value = point.altitude
        }

        guard let anchor = elevationAnchor else {
            elevationAnchor = value
            return
        }
        let diff = value - anchor
        guard abs(diff) > Self.elevationThreshold else { return }
        if diff > 0 {
            elevationGain += diff
        } else {
            elevationLoss += abs(diff)
        }
        elevationAnchor = value
    }

    /// Kalles når appen går i bakgrunnen. Da er den mest utsatt for å bli
    /// avlivet, og et sjekkpunkt akkurat der er billigere enn å miste
    /// minuttene siden forrige.
    func checkpointNow() {
        checkpoint()
    }

    func finish() -> ActivityResult {
        let endTime = Date()
        let duration = startTime.map { endTime.timeIntervalSince($0) } ?? 0
        // Journalen slettes bevisst *ikke* her. Den er turens eneste kopi helt
        // til lagringen i SwiftData har gått bra – feiler den, skal turen
        // fortsatt kunne gjenopprettes ved neste oppstart.
        let result = ActivityResult(
            trackPoints: trackPoints.map(Self.encode),
            distance: totalDistance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            duration: duration,
            startedAt: startTime ?? endTime,
            endedAt: endTime
        )
        // Økta er over: en fiks som fortsatt er underveis, skal ikke kunne
        // lagre punkter eller skrive et nytt sjekkpunkt.
        startTime = nil
        return result
    }

    /// Radformatet er additivt: de fire første tallene står der de alltid har
    /// stått, så turer tatt opp med eldre versjoner leses uendret. Nye felt
    /// legges bakerst, aldri imellom.
    private static func encode(_ point: TrackPoint) -> [Double] {
        var values: [Double] = [
            point.coordinate.longitude,
            point.coordinate.latitude,
            point.altitude,
            point.timestamp.timeIntervalSince1970,
            point.horizontalAccuracy,
            point.speed,
            point.course,
            point.verticalAccuracy
        ]
        // Barometrisk høyde legges bare til når den finnes. Lengden på raden
        // *er* signalet – da trengs ingen tallverdi som betyr «mangler», og
        // ingen kan forveksle den med en måling.
        if let relativeAltitude = point.relativeAltitude, relativeAltitude.isFinite {
            values.append(relativeAltitude)
        }
        return values
    }

    /// Motstykket til `encode`. Tåler både gamle firetallspunkter og nye
    /// åttetallspunkter, og forkaster rader som ikke gir mening som posisjon.
    private static func decode(_ values: [Double]) -> TrackPoint? {
        guard values.count >= 4 else { return nil }
        let longitude = values[0]
        let latitude = values[1]
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return TrackPoint(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: values[2],
            timestamp: Date(timeIntervalSince1970: values[3]),
            horizontalAccuracy: values.count >= 5 ? values[4] : -1,
            speed: values.count >= 6 ? values[5] : -1,
            course: values.count >= 7 ? values[6] : -1,
            verticalAccuracy: values.count >= 8 ? values[7] : (values[2] > 0 ? 0 : -1),
            relativeAltitude: values.count >= 9 ? values[8] : nil
        )
    }

    func currentStats() -> ActivityStats {
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        return ActivityStats(
            pointCount: trackPoints.count,
            distance: totalDistance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            duration: duration
        )
    }
}

struct ActivityResult: Sendable {
    let trackPoints: [[Double]]
    let distance: Double
    let elevationGain: Double
    let elevationLoss: Double
    let duration: TimeInterval
    let startedAt: Date
    let endedAt: Date
}

struct ActivityStats: Sendable {
    let pointCount: Int
    let distance: Double
    let elevationGain: Double
    let elevationLoss: Double
    let duration: TimeInterval
}
