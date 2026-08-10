import Foundation
import CoreLocation

// MARK: - Camera Mode

enum NavigationCameraMode: String, Sendable {
    case northUp
    case courseUp
}

// MARK: - Kameraets følgemodus

/// De tre tilstandene kameraet kan stå i, slik brukeren opplever dem. Samme
/// tredeling som `MKUserTrackingMode` (`.none`/`.follow`/`.followWithHeading`)
/// og som lokasjonsknappen i Apples Kart – kjenner du den ene, kjenner du den
/// andre.
///
/// Utledet, aldri lagret: kilden er `isCameraDetached`, `isTrackingUser` og
/// enten `isHeadingUp` (vanlig bruk) eller `NavigationCameraMode`
/// (navigasjon). En egen lagret variabel ville kunne komme ut av synk med hva
/// kartet faktisk gjør, og da lyver knappen.
enum MapCameraFollowMode: Sendable {
    /// Kartet står fritt. Enten fordi brukeren har flyttet det, eller fordi
    /// det aldri har fulgt posisjonen.
    case free
    /// Følger posisjonen din. Nord blir liggende opp.
    case followNorth
    /// Følger posisjonen din og roterer med retningen du går i.
    case followHeading

    static func current(
        isCameraDetached: Bool,
        isNavigating: Bool,
        navigationCameraMode: NavigationCameraMode,
        isTrackingUser: Bool,
        isHeadingUp: Bool
    ) -> MapCameraFollowMode {
        if isCameraDetached { return .free }
        if isNavigating {
            return navigationCameraMode == .courseUp ? .followHeading : .followNorth
        }
        if isHeadingUp { return .followHeading }
        // Utenfor navigasjon følger kartet bare når sporing faktisk er på.
        // Ved oppstart er den av, og da skal knappen si «fritt», ikke lyve om
        // at den følger deg.
        return isTrackingUser ? .followNorth : .free
    }

    /// Ikon som bærer tilstanden i *form*, ikke bare i farge – farge alene
    /// bryter WCAG 2.2 AA 1.4.1, og rød/grønn er dessuten den kombinasjonen
    /// flest ikke skiller. Samme progresjon som Apple Kart: åpen pil (følger
    /// ikke) → fylt pil (følger) → fylt pil med nordstrek (roterer med deg).
    var symbolName: String {
        switch self {
        case .free: return "location.north"
        case .followNorth: return "location.north.fill"
        case .followHeading: return "location.north.line.fill"
        }
    }

    var localizedName: String {
        switch self {
        case .free: return String(localized: "map.camera.free")
        case .followNorth: return String(localized: "map.camera.followNorth")
        case .followHeading: return String(localized: "map.camera.followHeading")
        }
    }
}

// MARK: - GPS Quality

/// Tersklene er strammet inn slik at de står i forhold til ankomstradiusen:
/// en fiks med 19 m usikkerhet ble tidligere meldt som god, samtidig som
/// avstandstallet ble vist på metersnivå. Nå får brukeren beskjed når tallet
/// er grovere enn det ser ut.
enum GPSQuality: Sendable {
    case good       // horizontalAccuracy < 10m
    case reduced    // horizontalAccuracy < 35m
    case lost       // horizontalAccuracy >= 35m or no signal

    init(accuracy: CLLocationAccuracy) {
        switch accuracy {
        case ..<0:
            self = .lost
        case ..<10:
            self = .good
        case ..<35:
            self = .reduced
        default:
            self = .lost
        }
    }
}
