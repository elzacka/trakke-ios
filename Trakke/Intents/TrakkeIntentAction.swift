import Foundation

/// En handling bestilt utenfra appen: fra Siri, Snarveier, Handlingsknappen
/// eller Spotlight.
///
/// Handlingen utføres ikke der og da. Den legges igjen her, appen åpnes, og
/// `AppLifecycleModifier` henter den så snart appen er aktiv.
///
/// Grunnen til omveien er posisjon. Både turopptak og «marker stedet» trenger
/// en GPS-fiks, og et intent som kjører uten grensesnitt har verken tillatelse
/// eller tid til å vente på en. Å åpne appen først er ærligere enn å starte et
/// opptak som ikke får posisjoner: brukeren ser at noe skjedde, og ser med én
/// gang om GPS-en er klar.
enum TrakkeIntentAction: String, Sendable {
    case startRecording
    case stopRecording
    case markCurrentPlace

    private static let key = "pendingIntentAction"

    /// Bestiller en handling. Overskriver en eventuell tidligere som ikke rakk
    /// å bli utført – to trykk på rad skal gi én handling, ikke en kø.
    func request() {
        UserDefaults.standard.set(rawValue, forKey: Self.key)
    }

    /// Henter og fjerner en bestilt handling. Fjerningen skjer her, ikke hos
    /// kalleren, slik at handlingen ikke kan bli utført to ganger om appen
    /// blir aktiv flere ganger raskt etter hverandre.
    static func take() -> TrakkeIntentAction? {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return TrakkeIntentAction(rawValue: raw)
    }
}
