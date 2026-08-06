import SwiftUI
import CoreLocation

/// Samler app-nivå dialoger (DB-recovery, lagrings-feil,
/// langt-trykk-meny) i én ViewModifier. Erstatter den tidligere private
/// `MainLayoutDialogsModifier` i `ContentView`.
struct DialogHost: ViewModifier {
    let coordinator: AppCoordinator
    let sheets: SheetCoordinator

    @Binding var longPressCoordinate: CLLocationCoordinate2D?
    @Binding var showDbRecoveryAlert: Bool

    func body(content: Content) -> some View {
        content
            .trakkeDialog(
                isPresented: $showDbRecoveryAlert,
                title: String(localized: "settings.dbRecovery.title"),
                message: String(localized: "settings.dbRecovery.message"),
                buttons: [.primary(String(localized: "common.ok")) {}]
            )
            .trakkeDialog(
                isPresented: saveErrorBinding,
                title: String(localized: "error.saveFailed"),
                message: saveErrorMessage,
                buttons: [.primary(String(localized: "common.ok")) {}]
            )
            .trakkeDialog(
                isPresented: longPressBinding,
                buttons: longPressDialogButtons
            )
    }

    // MARK: - Save Error

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { hasSaveError },
            set: { if !$0 { clearSaveErrors() } }
        )
    }

    private var hasSaveError: Bool {
        coordinator.routeViewModel.saveError != nil
            || coordinator.waypointViewModel.saveError != nil
            || coordinator.activityViewModel.saveError != nil
    }

    private var saveErrorMessage: String {
        coordinator.routeViewModel.saveError
            ?? coordinator.waypointViewModel.saveError
            ?? coordinator.activityViewModel.saveError
            ?? ""
    }

    private func clearSaveErrors() {
        coordinator.routeViewModel.saveError = nil
        coordinator.waypointViewModel.saveError = nil
        coordinator.activityViewModel.saveError = nil
    }

    // MARK: - Long Press

    private var longPressBinding: Binding<Bool> {
        Binding(
            get: { longPressCoordinate != nil },
            set: { if !$0 { longPressCoordinate = nil } }
        )
    }

    private var longPressDialogButtons: [TrakkeDialogButton] {
        [
            .primary(String(localized: "waypoints.addWaypoint"), action: addWaypointAtLongPress),
            .primary(String(localized: "navigation.navigateHere"), action: navigateToLongPress),
            // En handlingsliste trenger en synlig vei ut. Å trykke utenfor
            // lukker den også, men det er en skjult utvei – den som ikke
            // kjenner den, sitter fast i en dialog uten spørsmål.
            .cancel()
        ]
    }

    private func addWaypointAtLongPress() {
        guard let coord = longPressCoordinate else { return }
        coordinator.mapViewModel.searchPinCoordinate = nil
        coordinator.waypointViewModel.startPlacing(at: coord)
        sheets.editingWaypoint = nil
        DispatchQueue.main.async {
            sheets.active = .waypointEdit
        }
    }

    private func navigateToLongPress() {
        guard let coord = longPressCoordinate else { return }
        coordinator.mapViewModel.searchPinCoordinate = nil
        coordinator.startCompassNavigation(to: coord)
    }
}
