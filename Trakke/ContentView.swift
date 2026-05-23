import SwiftUI
import SwiftData
import CoreLocation

/// Interaktiv modus for hovedkartet. Bare én av gangen.
/// Rekkefølgen i `from(...)` definerer prioritet ved konflikt.
enum MapMode: Equatable {
    case idle
    case drawing
    case measuring
    case selecting
    case navigating

    static func from(
        isDrawing: Bool,
        isMeasuring: Bool,
        isSelecting: Bool,
        isNavigating: Bool
    ) -> MapMode {
        if isNavigating { return .navigating }
        if isSelecting { return .selecting }
        if isDrawing { return .drawing }
        if isMeasuring { return .measuring }
        return .idle
    }
}

struct ContentView: View {
    // State is internal so ContentView+* extensions in sibling files can read it.
    @State var mapViewModel = MapViewModel()
    @State var searchViewModel = SearchViewModel()
    @State var poiViewModel = POIViewModel()
    @State var routeViewModel = RouteViewModel()
    @State var waypointViewModel = WaypointViewModel()
    @State var offlineViewModel = OfflineViewModel()
    @State var weatherViewModel = WeatherViewModel()
    @State var measurementViewModel = MeasurementViewModel()
    @State var navigationViewModel = NavigationViewModel()
    @State var sosViewModel = SOSViewModel()
    @State var activityViewModel = ActivityViewModel()
    @State var knowledgeViewModel = KnowledgeViewModel()
    @State var sheets = SheetCoordinator()
    @State var connectivityMonitor = ConnectivityMonitor()
    @State var navigationDestination: CLLocationCoordinate2D?
    @State var isFABMenuOpen = false
    @State var selectedTab: AppTab = .home
    @State var sheetDetent: PresentationDetent = .large
    /// Non-nil while the long-press confirmation dialog is presented for the
    /// given coordinate. Nil dismisses the dialog. Replaces a paired
    /// (showLongPressOptions, longPressCoordinate) flag set.
    @State var longPressCoordinate: CLLocationCoordinate2D?
    @State var navigatingRouteId: String?
    @State var showRouteError = false
    @State var showRouteComputingIndicator = false
    @State var showStopConfirmation = false
    @State var showDbRecoveryAlert = false
    @State var isCleanMapActive = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppStorageKeys.showWeatherWidget) private var showWeatherWidget = false
    @AppStorage(AppStorageKeys.showCompass) private var showCompass = false
    @AppStorage(AppStorageKeys.showZoomControls) private var showZoomControls = false
    @AppStorage(AppStorageKeys.showScaleBar) private var showScaleBar = false
    @AppStorage(AppStorageKeys.enableRotation) private var enableRotation = true
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        mainLayout
        .onAppear {
            routeViewModel.setModelContext(modelContext)
            routeViewModel.loadRoutes()
            waypointViewModel.setModelContext(modelContext)
            waypointViewModel.loadWaypoints()
            activityViewModel.setModelContext(modelContext)
            activityViewModel.loadActivities()
            offlineViewModel.startObserving()
            connectivityMonitor.start()
            BundledPOIService.preloadAll()
            if UserDefaults.standard.bool(forKey: AppStorageKeys.dbRecoveryOccurred) {
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.dbRecoveryOccurred)
                showDbRecoveryAlert = true
            }
        }
        .onDisappear {
            offlineViewModel.stopObserving()
            connectivityMonitor.stop()
        }
        .onChange(of: searchViewModel.query) {
            mapViewModel.searchPinCoordinate = nil
        }
        .onChange(of: isFABMenuOpen) { _, isOpen in
            if isOpen {
                selectedTab = .home
                sheetDetent = .large
            }
        }
        .sheet(isPresented: $isFABMenuOpen) {
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
                onSearchResultSelected: { result in
                    mapViewModel.searchPinCoordinate = result.coordinate
                    mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
                    searchViewModel.clearSearch()
                    isFABMenuOpen = false
                },
                onStartCustomOfflineSelection: {
                    offlineViewModel.startSelection(
                        center: mapViewModel.currentCenter,
                        zoom: mapViewModel.currentZoom
                    )
                },
                onRouteSelected: { route in
                    isFABMenuOpen = false
                    startFollowingRoute(route)
                },
                onNewRoute: {
                    isFABMenuOpen = false
                    routeViewModel.startDrawing()
                },
                onWaypointEdit: { waypoint in
                    isFABMenuOpen = false
                    sheets.editingWaypoint = waypoint
                    // Defer sheet-presentasjon til etter AppMenuSheet er dismissed,
                    // ellers blokkerer den nye sheet-presentasjonen.
                    DispatchQueue.main.async {
                        sheets.active = .waypointEdit
                    }
                },
                onWaypointNavigate: { coordinate in
                    isFABMenuOpen = false
                    navigationDestination = coordinate
                    DispatchQueue.main.async {
                        sheets.active = .navigationStart
                    }
                },
                onActivitySelected: { _ in },
                onActivityRetrace: { coordinate in
                    isFABMenuOpen = false
                    navigationDestination = coordinate
                    sheets.active = .navigationStart
                },
                onActivityFollow: { activity in
                    isFABMenuOpen = false
                    followActivity(activity)
                },
                onStartRecording: {
                    isFABMenuOpen = false
                    startActivityRecording()
                },
                onDeleteAllData: clearAllServiceCaches
            )
            .presentationDetents([.medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.hidden)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .interactiveDismissDisabled(false)
        }
        .onChange(of: mapViewModel.locationAuthStatus) {
            if navigationViewModel.isActive,
               (mapViewModel.locationAuthStatus == .denied
                || mapViewModel.locationAuthStatus == .restricted) {
                stopNavigation()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background, navigationViewModel.isActive, !sosViewModel.isActive {
                // Ensure idle timer is restored if system terminates,
                // but keep it disabled when SOS signal is active
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onChange(of: mapViewModel.userLocation) {
            if let loc = mapViewModel.userLocation {
                offlineViewModel.checkOfflineAreaBoundary(
                    location: loc.coordinate,
                    isConnected: connectivityMonitor.isConnected
                )
            }
        }
        .onOpenURL { url in handleOpenedFile(url) }
        .task(id: navigationViewModel.isComputingRoute) {
            // Debounce indikatoren: vis først hvis beregningen tar mer enn 250 ms.
            // Stadia svarer typisk på ~120 ms; uten debounce flimrer kapselen.
            if navigationViewModel.isComputingRoute {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, navigationViewModel.isComputingRoute else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    showRouteComputingIndicator = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    showRouteComputingIndicator = false
                }
            }
        }
    }

    // MARK: - Clean Map

    private var effectiveShowCompass: Bool { isCleanMapActive ? false : showCompass }
    private var effectiveShowZoomControls: Bool { isCleanMapActive ? false : showZoomControls }
    private var effectiveShowScaleBar: Bool { isCleanMapActive ? false : showScaleBar }
    private var effectiveShowWeatherWidget: Bool { isCleanMapActive ? false : showWeatherWidget }
    private var effectiveOverlays: Set<OverlayLayer> { isCleanMapActive ? [] : mapViewModel.enabledOverlays }

    private func toggleCleanMap() {
        HapticFeedback.success()
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
            isCleanMapActive.toggle()
        }
    }

    // MARK: - Map Mode

    /// Avledet av view-model-tilstandene. Én sannhetsverdi for hva
    /// hovedkartet egentlig gjør akkurat nå.
    private var mapMode: MapMode {
        MapMode.from(
            isDrawing: routeViewModel.isDrawing,
            isMeasuring: measurementViewModel.isActive,
            isSelecting: offlineViewModel.isSelectingArea,
            isNavigating: navigationViewModel.isActive
        )
    }

    // MARK: - Map Tap Handler

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        switch mapMode {
        case .measuring: measurementViewModel.addPoint(coordinate)
        case .drawing: routeViewModel.addPoint(coordinate)
        case .idle, .selecting, .navigating: break
        }
    }

    // MARK: - Long Press Handler

    private func handleMapLongPress(_ coordinate: CLLocationCoordinate2D) {
        guard mapMode == .idle else { return }
        longPressCoordinate = coordinate
    }

    // MARK: - Viewport Handler

    private func handleViewportChanged(bounds: ViewportBounds, zoom: Double) {
        poiViewModel.viewportChanged(bounds: bounds, zoom: zoom)

        // Fetch weather for map center
        let center = CLLocationCoordinate2D(
            latitude: (bounds.north + bounds.south) / 2,
            longitude: (bounds.east + bounds.west) / 2
        )
        weatherViewModel.fetchForecast(for: center)
    }

    // MARK: - Main Layout

    private var mainLayout: some View {
        ZStack {
            TrakkeMapView(
                viewModel: mapViewModel,
                pois: poiViewModel.pois,
                routes: routeViewModel.visibleRoutes.filter { $0.id != navigatingRouteId },
                activities: activityViewModel.visibleActivities,
                waypoints: waypointViewModel.visibleWaypoints,
                drawingCoordinates: routeViewModel.drawingCoordinates,
                isDrawing: routeViewModel.isDrawing,
                selectionCorner1: offlineViewModel.selectionCorner1,
                selectionCorner2: offlineViewModel.selectionCorner2,
                measurementCoordinates: measurementViewModel.points,
                measurementMode: measurementViewModel.mode,
                searchPinCoordinate: mapViewModel.searchPinCoordinate,
                enabledOverlays: effectiveOverlays,
                showWeatherWidget: effectiveShowWeatherWidget,
                enableRotation: enableRotation,
                onViewportChanged: handleViewportChanged,
                onPOISelected: { poi in
                    poiViewModel.selectPOI(poi)
                    sheets.active = .poiDetail
                },
                onWaypointSelected: { wp in
                    waypointViewModel.selectedWaypoint = wp
                    sheets.active = .waypointDetail
                },
                onMapTapped: handleMapTap,
                onMapLongPressed: handleMapLongPress,
                onRoutePointDragged: { index, coord in
                    routeViewModel.movePoint(at: index, to: coord)
                },
                onMeasurementPointDragged: { index, coord in
                    measurementViewModel.movePoint(at: index, to: coord)
                },
                onSelectionCornerDragged: { index, coord in
                    offlineViewModel.moveSelectionCorner(at: index, to: coord)
                },
                offlinePackBounds: connectivityMonitor.isConnected ? [] : offlineViewModel.completedPackBounds,
                navigationRouteCoordinates: navigationViewModel.routeCoordinates,
                navigationSegmentIndex: navigationViewModel.snapResult?.segmentIndex ?? 0,
                isNavigating: navigationViewModel.isActive,
                navigationCameraMode: navigationViewModel.cameraMode,
                userHeading: mapViewModel.userHeading,
                compassDestination: navigationViewModel.destination,
                navigationMode: navigationViewModel.mode
            )
            .ignoresSafeArea()

            MapControlsOverlay(
                viewModel: mapViewModel,
                enabledOverlays: effectiveOverlays,
                isMenuOpen: $isFABMenuOpen,
                weatherContent: Group {
                    if effectiveShowWeatherWidget {
                        WeatherWidgetView(viewModel: weatherViewModel) {
                            sheets.active = .weather
                        }
                    }
                },
                showCompass: effectiveShowCompass,
                showZoomControls: effectiveShowZoomControls,
                showScaleBar: effectiveShowScaleBar,
                hideMenuAndZoom: mapMode != .idle || activityViewModel.isRecording,
                isConnected: connectivityMonitor.isConnected,
                isCleanMapActive: isCleanMapActive,
                onCleanMapToggle: toggleCleanMap,
                isInsideOfflineArea: !connectivityMonitor.isConnected && offlineViewModel.isInsideOfflineArea(mapViewModel.userLocation?.coordinate ?? mapViewModel.currentCenter)
            )

            if navigationViewModel.isActive {
                NavigationOverlayView(
                    navigationVM: navigationViewModel,
                    userHeading: mapViewModel.userHeading,
                    isConnected: connectivityMonitor.isConnected,
                    onStop: { showStopConfirmation = true },
                    onSwitchToCompass: { navigationViewModel.switchToCompass() },
                    onSwitchToRoute: {
                        guard !navigationViewModel.isComputingRoute,
                              let userLoc = mapViewModel.userLocation,
                              let dest = navigationViewModel.destination else { return }
                        Task {
                            let success = await navigationViewModel.startRouteNavigation(
                                from: userLoc.coordinate, to: dest
                            )
                            if !success { stopNavigation(); showRouteError = true }
                        }
                    },
                    onToggleCamera: { navigationViewModel.toggleCameraMode() },
                    onReroute: {
                        Task {
                            let success = await navigationViewModel.requestReroute()
                            if !success { showRouteError = true }
                        }
                    },
                    onSearchTapped: { sheets.active = .search },
                    onCategoryTapped: { sheets.active = .categoryPicker },
                    onEmergencyTapped: { sheets.active = .emergency },
                    onWeatherTapped: { sheets.active = .weather }
                )
                .trakkeDialog(
                    isPresented: $showStopConfirmation,
                    title: String(localized: "navigation.stopConfirmTitle"),
                    primary: .destructive(String(localized: "common.yes")) {
                        stopNavigation()
                    },
                    cancel: .cancel(String(localized: "common.no"))
                )
            }

            if showRouteComputingIndicator {
                VStack {
                    Spacer()
                    HStack(spacing: .Trakke.sm) {
                        ProgressView()
                            .tint(Color.Trakke.brand)
                        Text(String(localized: "navigation.computingRoute"))
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.text)
                    }
                    .padding(.horizontal, .Trakke.lg)
                    .padding(.vertical, .Trakke.sm)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, .Trakke.lg)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "navigation.computingRoute"))
                    .accessibilityAddTraits(.updatesFrequently)
                }
                .safeAreaPadding(.bottom)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            ModeToolbar(
                mode: mapMode,
                routeViewModel: routeViewModel,
                measurementViewModel: measurementViewModel,
                offlineViewModel: offlineViewModel,
                onRouteSave: { sheets.active = .routeSave },
                onDownloadArea: { sheets.active = .downloadArea }
            )

            if activityViewModel.isRecording {
                ActivityRecordingToolbar(
                    formattedDistance: activityViewModel.formattedDistance,
                    formattedDuration: activityViewModel.formattedDuration,
                    formattedElevationGain: activityViewModel.formattedElevationGain,
                    stackBelowNav: navigationViewModel.isActive,
                    onStop: { sheets.active = .activitySave }
                )
            }

            if mapViewModel.showLocationPrimer {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        mapViewModel.dismissLocationPrimer()
                    }
                    .accessibilityHidden(true)

                LocationPrimerView(
                    onAllow: { mapViewModel.confirmLocationPermission() },
                    onDismiss: { mapViewModel.dismissLocationPrimer() }
                )
                .transition(.opacity)
            }

            // Offline area warning toast
            if offlineViewModel.showLeftAreaWarning {
                OfflineWarningToast(viewModel: offlineViewModel)
            }

            // Download completion toast
            if offlineViewModel.completionMessage != nil {
                DownloadCompleteToast(viewModel: offlineViewModel)
            }
        }
        .tint(Color.Trakke.brand)
        .sheet(item: $sheets.active) { active in
            sheetContent(for: active)
        }
        .onChange(of: measurementViewModel.isActive) { _, isActive in
            if isActive, sheets.active == .measurement { sheets.active = nil }
        }
        .trakkeDialog(
            isPresented: $showRouteError,
            title: String(localized: "navigation.routeErrorTitle"),
            message: navigationViewModel.routeError ?? String(localized: "navigation.routeErrorGeneric"),
            buttons: [.primary(String(localized: "common.ok")) {}]
        )
        .trakkeDialog(
            isPresented: $showDbRecoveryAlert,
            title: String(localized: "settings.dbRecovery.title"),
            message: String(localized: "settings.dbRecovery.message"),
            buttons: [.primary(String(localized: "common.ok")) {}]
        )
        .trakkeDialog(
            isPresented: Binding(
                get: { routeViewModel.saveError != nil || waypointViewModel.saveError != nil || activityViewModel.saveError != nil },
                set: { if !$0 { routeViewModel.saveError = nil; waypointViewModel.saveError = nil; activityViewModel.saveError = nil } }
            ),
            title: String(localized: "error.saveFailed"),
            message: routeViewModel.saveError ?? waypointViewModel.saveError ?? activityViewModel.saveError ?? "",
            buttons: [.primary(String(localized: "common.ok")) {}]
        )
        .trakkeDialog(
            isPresented: Binding(
                get: { longPressCoordinate != nil },
                set: { if !$0 { longPressCoordinate = nil } }
            ),
            buttons: [
                .primary(String(localized: "waypoints.addWaypoint")) {
                    if let coord = longPressCoordinate {
                        waypointViewModel.startPlacing(at: coord)
                        sheets.editingWaypoint = nil
                        // Utsett sheet-presentasjon én runloop-tick så
                        // fullScreenCover-dialog rekker å dismisses før ny sheet
                        // prøver å presentere (unngår presentasjons-race).
                        DispatchQueue.main.async {
                            sheets.active = .waypointEdit
                        }
                    }
                },
                .primary(String(localized: "navigation.navigateHere")) {
                    if let coord = longPressCoordinate {
                        navigationDestination = coord
                        DispatchQueue.main.async {
                            sheets.active = .navigationStart
                        }
                    }
                },
                .cancel()
            ]
        )
    }

    // ModeToolbar moved to Views/Map/ModeToolbar.swift.

    // Sheet routing lives in Views/ContentView+Sheets.swift.

    // MARK: - GDPR Cache Clearing

    private func clearAllServiceCaches() {
        // GDPR: clear exported files synchronously since they may contain
        // user-visible route/activity data (GPX).
        GPXExportService.clearAllExports()
        Task {
            await weatherViewModel.clearCaches()
            await searchViewModel.clearCaches()
            await routeViewModel.clearCaches()
            await poiViewModel.clearCaches()
            await waypointViewModel.clearCaches()
            knowledgeViewModel.deleteAllPacks()
        }
    }

    // MARK: - Navigation
    // See ContentView+Navigation.swift for navigation method implementations.

    // OfflineWarningToast and DownloadCompleteToast moved to
    // Views/Components/OfflineToasts.swift.
}

#Preview {
    ContentView()
}
