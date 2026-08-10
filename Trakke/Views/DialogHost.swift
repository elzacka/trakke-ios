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

    /// Sier brukeren «Fortsett likevel», skal spørsmålet ligge til appen
    /// startes på nytt. Et varsel som kommer igjen med én gang er ikke et
    /// varsel, det er mas.
    @State private var reducedAccuracyDismissed = false

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
                isPresented: reducedAccuracyBinding,
                title: String(localized: "location.reducedAccuracy.title"),
                message: String(localized: "location.reducedAccuracy.message"),
                buttons: [
                    .primary(String(localized: "location.reducedAccuracy.allow")) {
                        Task { await coordinator.mapViewModel.requestFullAccuracy() }
                    },
                    .cancel(String(localized: "location.reducedAccuracy.continue"))
                ]
            )
            .trakkeDialog(
                isPresented: interruptedRecordingBinding,
                title: String(localized: "activity.interrupted.title"),
                message: interruptedRecordingMessage,
                buttons: [
                    .primary(String(localized: "activity.interrupted.resume")) {
                        coordinator.resumeInterruptedRecording()
                    },
                    .destructive(String(localized: "activity.interrupted.discard")) {
                        coordinator.activityViewModel.discardInterruptedRecording()
                    }
                ]
            )
            .trakkeDialog(
                isPresented: longPressBinding,
                buttons: longPressDialogButtons
            )
    }

    // MARK: - Nedgradert posisjon

    /// Med «Omtrentlig posisjon» bommer fiksene med kilometer. Navigasjonens
    /// fikspresisjonsfilter kaster dem, så HUD-en fryser i stedet for å lyve,
    /// men brukeren fikk aldri vite hvorfor. Nå spør appen én gang per økt om
    /// å få presis posisjon, og bare når noe faktisk trenger den.
    private var reducedAccuracyBinding: Binding<Bool> {
        Binding(
            get: { coordinator.mapViewModel.needsFullAccuracy && !reducedAccuracyDismissed },
            set: { if !$0 { reducedAccuracyDismissed = true } }
        )
    }

    // MARK: - Avbrutt opptak

    /// Dialogen har ingen «senere»-utvei med vilje. Journalen ligger der til
    /// den blir tatt stilling til, og et halvt svar ville bare gitt det samme
    /// spørsmålet ved neste oppstart – uten at brukeren visste hvorfor.
    private var interruptedRecordingBinding: Binding<Bool> {
        Binding(
            get: { coordinator.activityViewModel.interruptedRecording != nil },
            set: { _ in }
        )
    }

    private var interruptedRecordingMessage: String {
        guard let journal = coordinator.activityViewModel.interruptedRecording else { return "" }
        let started = journal.startedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            format: String(localized: "activity.interrupted.message %@ %lld"),
            started,
            journal.trackPoints.count
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
        // Utsettes alltid, ikke bare når et ark står åpent: dialogen som ble
        // trykket i lukkes i samme runde, og et ark presentert oppå den
        // avvisningen blir borte. Derfor ikke `sheets.present(_:)` her.
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
