import SwiftUI
import SwiftData
import UIKit

/// Samler alle `.onAppear`/`.onDisappear`/`.onChange`/`.task`-handlere som
/// tidligere lå spredt i `ContentView.body`. ViewModifier-formen gjør at
/// hver event-handler type-sjekkes uavhengig av ContentView-body, og
/// holder lifecycle-orkestrering atskilt fra layout og presentasjon.
struct AppLifecycleModifier: ViewModifier {
    let coordinator: AppCoordinator
    let sheets: SheetCoordinator
    let connectivityMonitor: ConnectivityMonitor

    @Binding var isFABMenuOpen: Bool
    @Binding var selectedTab: AppTab
    @Binding var sheetDetent: PresentationDetent
    @Binding var showDbRecoveryAlert: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onAppear(perform: handleOnAppear)
            .onDisappear(perform: handleOnDisappear)
            .onChange(of: isFABMenuOpen) { _, isOpen in
                handleFABMenuOpenChange(isOpen)
            }
            .onChange(of: coordinator.mapViewModel.locationAuthStatus) { _, _ in
                handleLocationAuthChange()
            }
            .onChange(of: scenePhase) { _, _ in
                handleScenePhaseChange()
            }
            .onChange(of: coordinator.mapViewModel.userLocation) { _, _ in
                handleUserLocationChange()
            }
            .onChange(of: coordinator.sosViewModel.isActive) { _, isActive in
                if !isActive { syncKeepAwake() }
            }
    }

    // MARK: - Handlers

    private func handleOnAppear() {
        coordinator.routeViewModel.setModelContext(modelContext)
        coordinator.routeViewModel.loadRoutes()
        coordinator.waypointViewModel.setModelContext(modelContext)
        coordinator.waypointViewModel.loadWaypoints()
        coordinator.activityViewModel.setModelContext(modelContext)
        coordinator.activityViewModel.loadActivities()
        coordinator.offlineViewModel.startObserving()
        coordinator.searchViewModel.setConnectivityMonitor(connectivityMonitor)
        connectivityMonitor.start()
        BundledPOIService.preload(coordinator.poiViewModel.enabledCategories)
        // Lå det igjen et opptak etter at appen døde, skal brukeren få vite
        // det med én gang – ikke oppdage det ved en tilfeldighet senere.
        coordinator.activityViewModel.checkForInterruptedRecording()
        // Ble appen startet av et intent, ligger handlingen allerede og venter.
        // `.active` kommer også ved kaldstart, men ikke alltid før første
        // `onAppear`, så begge stedene henter.
        performPendingIntentAction()
        if UserDefaults.standard.bool(forKey: AppStorageKeys.dbRecoveryOccurred) {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.dbRecoveryOccurred)
            showDbRecoveryAlert = true
        }
    }

    private func handleOnDisappear() {
        coordinator.offlineViewModel.stopObserving()
        connectivityMonitor.stop()
    }

    private func handleFABMenuOpenChange(_ isOpen: Bool) {
        if isOpen {
            selectedTab = .home
            // Åpne på halv skjerm, ikke full: menyen skal ikke dekke kartet
            // du nettopp navigerte til.
            sheetDetent = .medium
        }
    }

    private func handleLocationAuthChange() {
        guard coordinator.navigationViewModel.isActive else { return }
        let status = coordinator.mapViewModel.locationAuthStatus
        if status == .denied || status == .restricted {
            coordinator.stopNavigation()
        }
    }

    private func handleScenePhaseChange() {
        if scenePhase == .background {
            // Bakgrunnen er der appen står i størst fare for å bli avlivet.
            // Et sjekkpunkt her koster nesten ingenting og redder minuttene
            // siden forrige.
            coordinator.activityViewModel.checkpointRecording()
            if coordinator.navigationViewModel.isActive,
               !coordinator.sosViewModel.isActive {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            let hasActiveDownload = coordinator.offlineViewModel.packs.contains {
                !$0.progress.isComplete && !coordinator.offlineViewModel.isErrored($0)
            }
            if hasActiveDownload {
                coordinator.offlineViewModel.showDownloadBackgroundWarning = true
            }
        } else if scenePhase == .active {
            syncKeepAwake()
            performPendingIntentAction()
        }
    }

    /// Utfører en handling bestilt fra Siri, Snarveier, Handlingsknappen eller
    /// Spotlight. Ligger her fordi «stopp opptak» skal ende i lagre-arket,
    /// og arkene styres herfra, ikke fra `AppCoordinator`.
    ///
    /// Handlinger som allerede er i gang gjentas ikke: to trykk på «start
    /// opptak» skal ikke starte en ny tur oppå den som går.
    private func performPendingIntentAction() {
        guard let action = TrakkeIntentAction.take() else { return }
        switch action {
        case .startRecording:
            guard !coordinator.activityViewModel.isRecording else { return }
            coordinator.startActivityRecording()
        case .stopRecording:
            guard coordinator.activityViewModel.isRecording else { return }
            // Menyen kan ha stått åpen da appen ble sendt i bakgrunnen.
            let menuWasOpen = isFABMenuOpen
            isFABMenuOpen = false
            sheets.present(.activitySave, otherSheetIsOpen: menuWasOpen)
        case .markCurrentPlace:
            coordinator.markCurrentPlace()
        }
    }

    /// Turopptak holder ikke lenger skjermen våken. Det var en nødløsning for
    /// at opptaket stoppet ved skjermlås; nå fortsetter det i bakgrunnen, og
    /// et batteri som varer hele turen er verdt mer enn et tent display.
    private func syncKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled =
            coordinator.navigationViewModel.isActive ||
            coordinator.sosViewModel.isActive
    }

    private func handleUserLocationChange() {
        guard let loc = coordinator.mapViewModel.userLocation else { return }
        coordinator.offlineViewModel.checkOfflineAreaBoundary(
            location: loc.coordinate,
            isConnected: connectivityMonitor.isConnected
        )
    }

}
