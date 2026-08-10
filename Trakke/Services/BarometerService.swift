import CoreMotion
import Foundation

/// Barometeret i telefonen, brukt til høyde og trykkutvikling.
///
/// GPS-høyde er den svakeste verdien GPS-en gir – typisk ti til tjue meter feil,
/// og verre under bratte fjellsider der satellittene bare sees i én retning.
/// Barometeret måler ikke høyde over havet direkte, men det måler *endring* i
/// høyde langt mer presist, og det er endringen høydemeterne er summen av.
///
/// Like viktig i felt: det virker uten satellittsignal. I skog, i skar, i
/// tåke og under en snøvegg fortsetter høydeprofilen å bli riktig selv når
/// posisjonen er usikker.
///
/// Trykket i seg selv er et værtegn. Fallende trykk over noen timer varsler
/// forverring, og det er en observasjon telefonen gjør lokalt – uten nett, som
/// er nettopp når en værmelding ikke er tilgjengelig.
///
/// Målingene forlater aldri enheten. `CMAltimeter` krever
/// `NSMotionUsageDescription`, og tilgangen kan være avslått; da faller alt
/// tilbake på GPS-høyde uten at noe annet merker det.
actor BarometerService {
    /// Relativ høyde i meter siden målingen startet, og lufttrykk i
    /// hektopascal. Begge `nil` før første måling.
    private(set) var relativeAltitude: Double?
    private(set) var pressure: Double?

    /// Trykkmålinger med tidspunkt, brukt til å se utviklingen. Bare de siste
    /// timene beholdes – eldre målinger sier ingenting om været som kommer.
    private var pressureHistory: [(date: Date, hPa: Double)] = []
    private static let historyWindow: TimeInterval = 3 * 3600

    private let altimeter = CMAltimeter()
    private var isRunning = false

    /// Enheten har barometer *og* brukeren har gitt tilgang.
    static var isAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    static var authorizationStatus: CMAuthorizationStatus {
        CMAltimeter.authorizationStatus()
    }

    func start() {
        guard Self.isAvailable, !isRunning else { return }
        isRunning = true
        relativeAltitude = nil
        pressure = nil
        pressureHistory = []

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let data, error == nil else { return }
            // kPa fra CoreMotion, hPa er enheten værmeldinger bruker.
            let hPa = data.pressure.doubleValue * 10
            let metres = data.relativeAltitude.doubleValue
            let timestamp = Date()
            Task { [weak self] in
                await self?.record(relativeAltitude: metres, pressure: hPa, at: timestamp)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        altimeter.stopRelativeAltitudeUpdates()
    }

    private func record(relativeAltitude metres: Double, pressure hPa: Double, at date: Date) {
        guard metres.isFinite, hPa.isFinite, hPa > 0 else { return }
        relativeAltitude = metres
        pressure = hPa
        pressureHistory.append((date, hPa))
        let cutoff = date.addingTimeInterval(-Self.historyWindow)
        pressureHistory.removeAll { $0.date < cutoff }
    }

    /// Trykkendring i hektopascal per time, regnet over hele vinduet som
    /// finnes. `nil` før det er nok målinger til å si noe.
    ///
    /// Tommelfingerregelen i felt: raskere fall enn omtrent 1 hPa i timen
    /// varsler forverring, og mer enn 2 varsler at det haster.
    func pressureTrend() -> Double? {
        guard let first = pressureHistory.first, let last = pressureHistory.last else { return nil }
        let hours = last.date.timeIntervalSince(first.date) / 3600
        // Under et kvarter er forskjellen mest støy og pust på sensoren.
        guard hours >= 0.25 else { return nil }
        return (last.hPa - first.hPa) / hours
    }
}
