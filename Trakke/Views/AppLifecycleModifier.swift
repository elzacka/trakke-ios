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
            .onChange(of: coordinator.measurementViewModel.isActive) { _, isActive in
                handleMeasurementActiveChange(isActive)
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
        BundledPOIService.preloadAll()
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
            sheetDetent = .large
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
        }
    }

    private func syncKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled =
            coordinator.navigationViewModel.isActive ||
            coordinator.activityViewModel.isRecording ||
            coordinator.sosViewModel.isActive
    }

    private func handleUserLocationChange() {
        guard let loc = coordinator.mapViewModel.userLocation else { return }
        coordinator.offlineViewModel.checkOfflineAreaBoundary(
            location: loc.coordinate,
            isConnected: connectivityMonitor.isConnected
        )
    }

    private func handleMeasurementActiveChange(_ isActive: Bool) {
        if isActive, sheets.active == .measurement {
            sheets.active = nil
        }
    }

}
