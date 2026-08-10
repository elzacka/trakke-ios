import AppIntents
import Foundation

/// Handlinger Tråkke tilbyr utenfor appen: Siri, Snarveier, Handlingsknappen
/// og Spotlight.
///
/// Alle flatene bygger på de samme intentene, så én implementasjon dekker dem.
/// Det praktiske problemet de løser er felles: å starte et turopptak eller
/// markere et sted med votter på, i regn, uten å låse opp telefonen og lete
/// seg gjennom en meny.
///
/// Kontrollsenter er *ikke* med. En flis der krever en egen `ControlWidget` i
/// widget-utvidelsen, ikke bare et intent, og den finnes ikke. Intentene under
/// ville fungert uendret om den ble laget.
///
/// Alle intentene åpner appen (`openAppWhenRun`). Se `TrakkeIntentAction` for
/// hvorfor.

// MARK: - Start turopptak

struct StartTripRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start turopptak"
    static let description = IntentDescription(
        "Åpner Tråkke og begynner å ta opp turen."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TrakkeIntentAction.startRecording.request()
        return .result()
    }
}

// MARK: - Stopp turopptak

struct StopTripRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stopp turopptak"
    static let description = IntentDescription(
        "Åpner Tråkke og avslutter opptaket, slik at du kan lagre turen."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TrakkeIntentAction.stopRecording.request()
        return .result()
    }
}

// MARK: - Marker stedet

struct MarkCurrentPlaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Marker stedet"
    static let description = IntentDescription(
        "Åpner Tråkke og lagrer posisjonen din som et sted."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TrakkeIntentAction.markCurrentPlace.request()
        return .result()
    }
}

// MARK: - Talefraser

/// Frasene må inneholde appnavnet. Flere varianter per handling fordi folk
/// sier det ulikt, og fordi Siri ikke gjetter.
struct TrakkeShortcuts: AppShortcutsProvider {
    /// Fargen på snarveiflisene i Snarveier og Spotlight. Uten et valg her
    /// arver de en systemfarge, og Tråkke ville stått med en blå flis i en app
    /// som ellers ikke bruker blått noe sted. `ShortcutTileColor` er en fast
    /// liste, og `.grayGreen` ligger nærmest den dempede skogsgrønnen i
    /// `Color.Trakke.brand` (#3e4533). `.lime` og `.teal` er begge for mettede.
    static let shortcutTileColor: ShortcutTileColor = .grayGreen

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripRecordingIntent(),
            phrases: [
                "Start turopptak i \(.applicationName)",
                "Ta opp tur i \(.applicationName)",
                "Start tur i \(.applicationName)"
            ],
            shortTitle: "Start turopptak",
            systemImageName: "record.circle"
        )
        AppShortcut(
            intent: StopTripRecordingIntent(),
            phrases: [
                "Stopp turopptak i \(.applicationName)",
                "Avslutt turen i \(.applicationName)"
            ],
            shortTitle: "Stopp turopptak",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: MarkCurrentPlaceIntent(),
            phrases: [
                "Marker stedet i \(.applicationName)",
                "Lagre stedet i \(.applicationName)",
                "Nytt sted i \(.applicationName)"
            ],
            shortTitle: "Marker stedet",
            systemImageName: "mappin.and.ellipse"
        )
    }
}
