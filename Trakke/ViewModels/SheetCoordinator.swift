import SwiftUI

/// Hvilken sheet som er aktiv. Kun én kan være åpen om gangen.
enum ActiveSheet: Identifiable, Hashable {
    case search
    case categoryPicker
    case poiDetail
    case routeList
    case routeSave
    case bibliotek
    case waypointList
    case waypointDetail
    case waypointEdit
    case offlineManager
    case downloadArea
    case offlineSetup
    case weather
    case measurement
    case navigationStart
    case emergency
    case activityList
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

    /// Hvilken fane Bibliotek skal åpne på. Settes før `active = .bibliotek`.
    var bibliotekInitialTab: BibliotekTab = .myStuff

    func present(_ sheet: ActiveSheet) {
        active = sheet
    }

    func openBibliotek(at tab: BibliotekTab) {
        bibliotekInitialTab = tab
        active = .bibliotek
    }

    func dismiss() {
        active = nil
    }

    func dismissAll() {
        active = nil
        editingWaypoint = nil
    }
}
