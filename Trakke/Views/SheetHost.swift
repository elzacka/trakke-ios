import SwiftUI
import CoreLocation

/// Eier all sheet-presentasjon: hoved-sheet-routing via `SheetCoordinator`
/// og FAB-menyen som åpnes med den grønne menyknappen.
///
/// Tidligere lå `sheetContent(for:)` i `ContentView+Sheets.swift`
/// (extension) og `appMenuSheetContent` med ti callbacks inne i `ContentView`.
/// Begge er flyttet hit slik at sheet-laget type-sjekkes uavhengig og
/// holdes atskilt fra layout og lifecycle.
struct SheetHost: ViewModifier {
    let coordinator: AppCoordinator
    let sheets: SheetCoordinator
    let connectivityMonitor: ConnectivityMonitor

    @Binding var isFABMenuOpen: Bool
    @Binding var selectedTab: AppTab
    @Binding var sheetDetent: PresentationDetent

    // Aliaser så hver call-site type-sjekkes isolert.
    private var mapViewModel: MapViewModel { coordinator.mapViewModel }
    private var searchViewModel: SearchViewModel { coordinator.searchViewModel }
    private var poiViewModel: POIViewModel { coordinator.poiViewModel }
    private var routeViewModel: RouteViewModel { coordinator.routeViewModel }
    private var waypointViewModel: WaypointViewModel { coordinator.waypointViewModel }
    private var offlineViewModel: OfflineViewModel { coordinator.offlineViewModel }
    private var weatherViewModel: WeatherViewModel { coordinator.weatherViewModel }
    private var measurementViewModel: MeasurementViewModel { coordinator.measurementViewModel }
    private var sosViewModel: SOSViewModel { coordinator.sosViewModel }
    private var activityViewModel: ActivityViewModel { coordinator.activityViewModel }
    private var knowledgeViewModel: KnowledgeViewModel { coordinator.knowledgeViewModel }

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding(
                get: { sheets.active },
                set: { sheets.active = $0 }
            )) { active in
                sheetContent(for: active)
            }
            .sheet(isPresented: $isFABMenuOpen) {
                appMenuSheetContent
            }
    }

    // MARK: - FAB Menu Sheet

    @ViewBuilder
    private var appMenuSheetContent: some View {
        AppMenuSheet(
            selectedTab: $selectedTab,
            poiViewModel: poiViewModel,
            searchViewModel: searchViewModel,
            mapViewModel: mapViewModel,
            weatherViewModel: weatherViewModel,
            knowledgeViewModel: knowledgeViewModel,
            measurementViewModel: measurementViewModel,
            offlineViewModel: offlineViewModel,
            sosViewModel: sosViewModel,
            routeViewModel: routeViewModel,
            waypointViewModel: waypointViewModel,
            activityViewModel: activityViewModel,
            connectivityMonitor: connectivityMonitor,
            onSearchResultSelected: handleSearchResult,
            onStartCustomOfflineSelection: startCustomOfflineSelection,
            onRouteSelected: handleRouteSelected,
            onNewRoute: handleNewRoute,
            onWaypointEdit: handleWaypointEdit,
            onWaypointNavigate: handleWaypointNavigate,
            onActivitySelected: { _ in },
            onActivityRetrace: handleActivityRetrace,
            onActivityFollow: handleActivityFollow,
            onStartRecording: handleStartRecording,
            onDeleteAllData: coordinator.clearAllServiceCaches,
            onClose: { isFABMenuOpen = false }
        )
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        // Et sveip i innholdet ruller, det drar ikke arket opp i fullhøyde. Da
        // kan du skru ting av og på i Innstillinger og se kartet samtidig.
        // Høyden endres i stedet ved å dra i grabberen, som alle fem fanene
        // tegner via `TrakkeSheetHeader` over rullefeltet – derfor er systemets
        // egen indikator fortsatt skjult, ellers ville det blitt to.
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.hidden)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        // Aktivt SOS-signal (via Verktøy-fanen) skal ikke kunne dras vekk –
        // samme regel som det frittstående nødarket.
        .interactiveDismissDisabled(sosViewModel.isActive)
    }

    // MARK: - FAB Menu Callbacks
    //
    // Egne metoder så type-checkeren slipper å resolve hver lukkings-
    // closure inni AppMenuSheet-initialiseringen.

    private func handleSearchResult(_ result: SearchResult) {
        mapViewModel.searchPinCoordinate = result.coordinate
        mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
        searchViewModel.clearSearch()
        isFABMenuOpen = false
    }

    private func startCustomOfflineSelection() {
        mapViewModel.searchPinCoordinate = nil
        offlineViewModel.startSelection(
            center: mapViewModel.currentCenter,
            zoom: mapViewModel.currentZoom
        )
    }

    private func handleRouteSelected(_ route: Route) {
        isFABMenuOpen = false
        coordinator.startFollowingRoute(route)
    }

    private func handleNewRoute() {
        isFABMenuOpen = false
        mapViewModel.searchPinCoordinate = nil
        routeViewModel.startDrawing()
    }

    private func handleWaypointEdit(_ waypoint: Waypoint) {
        let menuWasOpen = isFABMenuOpen
        isFABMenuOpen = false
        sheets.editingWaypoint = waypoint
        sheets.present(.waypointEdit, otherSheetIsOpen: menuWasOpen)
    }

    private func handleWaypointNavigate(_ coordinate: CLLocationCoordinate2D) {
        isFABMenuOpen = false
        coordinator.startCompassNavigation(to: coordinate)
    }

    private func handleActivityRetrace(_ coordinate: CLLocationCoordinate2D) {
        isFABMenuOpen = false
        coordinator.startCompassNavigation(to: coordinate)
    }

    private func handleActivityFollow(_ activity: Activity) {
        isFABMenuOpen = false
        coordinator.followActivity(activity)
    }

    private func handleStartRecording() {
        isFABMenuOpen = false
        coordinator.startActivityRecording()
    }

    // MARK: - Sheet Routing

    @ViewBuilder
    private func sheetContent(for active: ActiveSheet) -> some View {
        switch active {
        case .poiDetail:
            if let poi = poiViewModel.selectedPOI {
                POIDetailSheet(
                    poi: poi,
                    onNavigate: { coordinate in
                        coordinator.startCompassNavigation(to: coordinate)
                        sheets.active = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
            }

        case .tracks:
            TracksListSheet(
                routeViewModel: routeViewModel,
                activityViewModel: activityViewModel,
                onRouteSelected: { route in
                    sheets.active = nil
                    coordinator.startFollowingRoute(route)
                },
                onActivityRetrace: { coordinate in
                    coordinator.startCompassNavigation(to: coordinate)
                    sheets.active = nil
                },
                onActivityFollow: { activity in
                    sheets.active = nil
                    coordinator.followActivity(activity)
                },
                onNewRoute: {
                    mapViewModel.searchPinCoordinate = nil
                    routeViewModel.startDrawing()
                },
                onStartRecording: {
                    coordinator.startActivityRecording()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))

        case .routeSave:
            RouteSaveSheet(viewModel: routeViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))

        case .waypointList:
            WaypointListSheet(
                viewModel: waypointViewModel,
                onWaypointSelected: { _ in },
                onWaypointEdit: { wp in
                    sheets.editingWaypoint = wp
                    sheets.present(.waypointEdit)
                },
                onWaypointNavigate: { coordinate in
                    coordinator.startCompassNavigation(to: coordinate)
                    sheets.active = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))

        case .waypointDetail:
            if let wp = waypointViewModel.selectedWaypoint {
                WaypointDetailSheet(
                    viewModel: waypointViewModel,
                    waypoint: wp,
                    onEdit: { waypoint in
                        sheets.editingWaypoint = waypoint
                        sheets.present(.waypointEdit)
                    },
                    onNavigate: { coordinate in
                        coordinator.startCompassNavigation(to: coordinate)
                        sheets.active = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
            }

        case .waypointEdit:
            WaypointEditSheet(
                viewModel: waypointViewModel,
                editingWaypoint: sheets.editingWaypoint
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))

        case .downloadArea:
            DownloadAreaSheet(viewModel: offlineViewModel)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))

        case .weather:
            WeatherSheet(viewModel: weatherViewModel)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))

        case .activitySave:
            ActivitySaveSheet(viewModel: activityViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
    }
}
