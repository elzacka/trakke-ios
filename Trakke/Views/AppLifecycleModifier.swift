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
            .task(id: coordinator.navigationViewModel.isComputingRoute) {
                await handleComputingIndicatorChange()
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
        if scenePhase == .background,
           coordinator.navigationViewModel.isActive,
           !coordinator.sosViewModel.isActive {
            // Ensure idle timer is restored if system terminates, but keep
            // it disabled when SOS signal is active.
            UIApplication.shared.isIdleTimerDisabled = false
        }
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

    private func handleComputingIndicatorChange() async {
        // Debounce indikatoren: vis først hvis beregningen tar mer enn 250 ms.
        // Stadia svarer typisk på ~120 ms; uten debounce flimrer kapselen.
        if coordinator.navigationViewModel.isComputingRoute {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled,
                  coordinator.navigationViewModel.isComputingRoute else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                coordinator.showRouteComputingIndicator = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                coordinator.showRouteComputingIndicator = false
            }
        }
    }
}
