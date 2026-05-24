import SwiftUI

/// Hvilken sheet som er aktiv. Kun én kan være åpen om gangen.
enum ActiveSheet: Identifiable, Hashable {
    case search
    case categoryPicker
    case poiDetail
    /// Sammenslaatt liste over ruter (planlagte/importerte linjer) og turer
    /// (GPS-opptak). Erstatter de tidligere `.routeList` og `.activityList`
    /// arkene som var separat. Tittel: «Turer og ruter».
    case tracks
    case routeSave
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

    func present(_ sheet: ActiveSheet) {
        active = sheet
    }

    func dismiss() {
        active = nil
    }

    func dismissAll() {
        active = nil
        editingWaypoint = nil
    }
}
