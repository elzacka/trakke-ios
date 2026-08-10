import SwiftUI

/// Hvilken sheet som er aktiv. Kun én kan være åpen om gangen.
enum ActiveSheet: Identifiable, Hashable {
    case poiDetail
    /// Sammenslaatt liste over ruter (planlagte/importerte linjer) og turer
    /// (GPS-opptak). Erstatter de tidligere `.routeList` og `.activityList`
    /// arkene som var separat. Tittel: «Turer og ruter».
    case tracks
    case routeSave
    case waypointList
    case waypointDetail
    case waypointEdit
    case downloadArea
    case weather
    case activitySave

    var id: Self { self }
}

/// Sentral plassering for hvilken sheet ContentView viser.
/// Erstatter 25 separate booleans med én `ActiveSheet?`.
@MainActor
@Observable
final class SheetCoordinator {
    /// Aktiv sheet, eller nil hvis ingen er presentert.
    var active: ActiveSheet?

    /// Waypoint som redigeres i `.waypointEdit`. Settes før `active = .waypointEdit`.
    var editingWaypoint: Waypoint?

    /// Presenterer et ark, også når noe annet alt står åpent.
    ///
    /// SwiftUI presenterer bare ett ark per view om gangen. `SheetHost` har to
    /// `.sheet`-modifikatorer – arkrutingen her og FAB-menyen – så å sette
    /// `active` mens noe annet vises gir «Currently, only presenting a single
    /// sheet is supported» i konsollen, og arket brukeren ba om kommer ikke før
    /// hen selv lukker det som står der. Det ser ut som et dødt trykk.
    ///
    /// Dette er ikke et kanttilfelle: kartet er tappbart bak arkene
    /// (`presentationBackgroundInteraction` på `.medium`-detent, se
    /// `MapScreen.handleMapTap`), så «meny åpen, trykk på en POI» er helt vanlig
    /// bruk. Det samme gjelder bytte fra ett ark til et annet, som når
    /// «Rediger» i stedslista skal åpne redigeringsarket.
    ///
    /// Løsningen er å lukke først og presentere på neste runde av kjøresløyfa.
    /// Når ingenting vises, presenteres arket direkte – et utsatt trykk ville
    /// kostet et bilde med forsinkelse i det vanligste tilfellet.
    ///
    /// - Parameter otherSheetIsOpen: om FAB-menyen står åpen. Den eies av
    ///   `ContentView`, ikke av denne klassen, så kalleren må si fra.
    func present(_ sheet: ActiveSheet, otherSheetIsOpen: Bool = false) {
        generation &+= 1
        let requested = generation

        guard active != nil || otherSheetIsOpen else {
            active = sheet
            return
        }
        active = nil
        DispatchQueue.main.async { [self] in
            // Enhver senere present/dismiss opphever denne. Uten sjekken kunne
            // et utsatt ark dukke opp igjen etter «Slett alle data» og vise
            // det som nettopp ble slettet.
            guard generation == requested else { return }
            active = sheet
        }
    }

    func dismiss() {
        generation &+= 1
        active = nil
    }

    func dismissAll() {
        generation &+= 1
        active = nil
        editingWaypoint = nil
    }

    /// Teller for å avbryte utsatte presentasjoner. Samme mønster som
    /// `SOSService`: en eldre, planlagt operasjon skal aldri overkjøre en nyere.
    private var generation = 0
}
