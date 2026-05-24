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
        bodyWithEventHandling
            .onOpenURL(perform: handleOpenedFile)
            .task(id: navigationViewModel.isComputingRoute) {
                await handleComputingIndicatorChange()
            }
    }

    /// Mellomledd som splitter modifier-kjeden i body i to lag. Uten denne
    /// splittingen blir den fulle kjeden på 10 modifikatorer for kompleks
    /// for SwiftUI-type-checkeren (>300 ms — over 200 ms-grensen lokalt,
    /// timeout på CI's eldre Xcode-versjon).
    @ViewBuilder
    private var bodyWithEventHandling: some View {
        mainLayout
            .onAppear(perform: handleOnAppear)
            .onDisappear(perform: handleOnDisappear)
            .onChange(of: searchViewModel.query) { _, _ in
                mapViewModel.searchPinCoordinate = nil
            }
            .onChange(of: isFABMenuOpen) { _, isOpen in
                handleFABMenuOpenChange(isOpen)
            }
            .sheet(isPresented: $isFABMenuOpen) { appMenuSheetContent }
            .onChange(of: mapViewModel.locationAuthStatus) { _, _ in
                handleLocationAuthChange()
            }
            .onChange(of: scenePhase) { _, _ in
                handleScenePhaseChange()
            }
            .onChange(of: mapViewModel.userLocation) { _, _ in
                handleUserLocationChange()
            }
    }

    // MARK: - Body lifecycle handlers
    //
    // Hver onAppear/onChange/task får en egen metode i stedet for inline
    // closure. Det reduserer body-uttrykkets type-checker-tid betraktelig
    // — uten denne splittingen tar uttrykket >300 ms lokalt og krasjer
    // på CI's strengere budsjett (Xcode 26.3 vs 26.5).

    private func handleOnAppear() {
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

    private func handleOnDisappear() {
        offlineViewModel.stopObserving()
        connectivityMonitor.stop()
    }

    private func handleFABMenuOpenChange(_ isOpen: Bool) {
        if isOpen {
            selectedTab = .home
            sheetDetent = .large
        }
    }

    private func handleLocationAuthChange() {
        guard navigationViewModel.isActive else { return }
        let status = mapViewModel.locationAuthStatus
        if status == .denied || status == .restricted {
            stopNavigation()
        }
    }

    private func handleScenePhaseChange() {
        if scenePhase == .background, navigationViewModel.isActive, !sosViewModel.isActive {
            // Ensure idle timer is restored if system terminates, but keep
            // it disabled when SOS signal is active
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func handleUserLocationChange() {
        guard let loc = mapViewModel.userLocation else { return }
        offlineViewModel.checkOfflineAreaBoundary(
            location: loc.coordinate,
            isConnected: connectivityMonitor.isConnected
        )
    }

    private func handleComputingIndicatorChange() async {
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

    // MARK: - App Menu Sheet
    //
    // Ekstrahert fra body.sheet for å hjelpe type-checkeren — uten denne
    // splittingen feiler ContentView-kompilering med "compiler is unable
    // to type-check this expression in reasonable time" på eldre Xcode-
    // versjoner (CI bruker 26.3, lokalt 26.5 takler det med advarsel).

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
            onDeleteAllData: clearAllServiceCaches
        )
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.hidden)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .interactiveDismissDisabled(false)
    }

    // App-meny callbacks — egne metoder så type-checkeren slipper å
    // resolve hver lukkings-closure inni AppMenuSheet-initialiseringen.

    private func handleSearchResult(_ result: SearchResult) {
        mapViewModel.searchPinCoordinate = result.coordinate
        mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
        searchViewModel.clearSearch()
        isFABMenuOpen = false
    }

    private func startCustomOfflineSelection() {
        offlineViewModel.startSelection(
            center: mapViewModel.currentCenter,
            zoom: mapViewModel.currentZoom
        )
    }

    private func handleRouteSelected(_ route: Route) {
        isFABMenuOpen = false
        startFollowingRoute(route)
    }

    private func handleNewRoute() {
        isFABMenuOpen = false
        routeViewModel.startDrawing()
    }

    private func handleWaypointEdit(_ waypoint: Waypoint) {
        isFABMenuOpen = false
        sheets.editingWaypoint = waypoint
        // Defer sheet-presentasjon til etter AppMenuSheet er dismissed,
        // ellers blokkerer den nye sheet-presentasjonen.
        DispatchQueue.main.async {
            sheets.active = .waypointEdit
        }
    }

    private func handleWaypointNavigate(_ coordinate: CLLocationCoordinate2D) {
        isFABMenuOpen = false
        navigationDestination = coordinate
        DispatchQueue.main.async {
            sheets.active = .navigationStart
        }
    }

    private func handleActivityRetrace(_ coordinate: CLLocationCoordinate2D) {
        isFABMenuOpen = false
        navigationDestination = coordinate
        sheets.active = .navigationStart
    }

    private func handleActivityFollow(_ activity: Activity) {
        isFABMenuOpen = false
        followActivity(activity)
    }

    private func handleStartRecording() {
        isFABMenuOpen = false
        startActivityRecording()
    }

    // MARK: - Map Layer
    //
    // Ekstrahert ut av mainLayout. TrakkeMapView har 30+ argumenter og
    // type-checker-tid skalerer med antall closures — å la den stå
    // inline i ZStack belastet body-uttrykket over CI-budsjettet.

    @ViewBuilder
    private var mapLayer: some View {
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
            onPOISelected: handlePOISelected,
            onWaypointSelected: handleWaypointSelected,
            onMapTapped: handleMapTap,
            onMapLongPressed: handleMapLongPress,
            onRoutePointDragged: handleRoutePointDragged,
            onMeasurementPointDragged: handleMeasurementPointDragged,
            onSelectionCornerDragged: handleSelectionCornerDragged,
            offlinePackBounds: offlinePackBounds,
            navigationRouteCoordinates: navigationViewModel.routeCoordinates,
            navigationSegmentIndex: navigationViewModel.snapResult?.segmentIndex ?? 0,
            isNavigating: navigationViewModel.isActive,
            navigationCameraMode: navigationViewModel.cameraMode,
            userHeading: mapViewModel.userHeading,
            compassDestination: navigationViewModel.destination,
            navigationMode: navigationViewModel.mode
        )
        .ignoresSafeArea()
    }

    private var offlinePackBounds: [(south: Double, west: Double, north: Double, east: Double)] {
        connectivityMonitor.isConnected ? [] : offlineViewModel.completedPackBounds
    }

    private func handlePOISelected(_ poi: POI) {
        poiViewModel.selectPOI(poi)
        sheets.active = .poiDetail
    }

    private func handleWaypointSelected(_ wp: Waypoint) {
        waypointViewModel.selectedWaypoint = wp
        sheets.active = .waypointDetail
    }

    private func handleRoutePointDragged(index: Int, coord: CLLocationCoordinate2D) {
        routeViewModel.movePoint(at: index, to: coord)
    }

    private func handleMeasurementPointDragged(index: Int, coord: CLLocationCoordinate2D) {
        measurementViewModel.movePoint(at: index, to: coord)
    }

    private func handleSelectionCornerDragged(index: Int, coord: CLLocationCoordinate2D) {
        offlineViewModel.moveSelectionCorner(at: index, to: coord)
    }

    // MARK: - Layout components (extracted from mainLayout)
    //
    // Hver lag ekstrahert til egen @ViewBuilder-property slik at
    // type-checkeren resolver dem isolert. Uten splittingen brukte
    // ContentView-body >300ms på type-checking lokalt og krasjet på
    // CI's strengere budsjett (Xcode 26.3).

    @ViewBuilder
    private var mapControlsLayer: some View {
        MapControlsOverlay(
            viewModel: mapViewModel,
            enabledOverlays: effectiveOverlays,
            isMenuOpen: $isFABMenuOpen,
            weatherContent: weatherWidgetContent,
            showCompass: effectiveShowCompass,
            showZoomControls: effectiveShowZoomControls,
            showScaleBar: effectiveShowScaleBar,
            hideMenuAndZoom: mapMode != .idle || activityViewModel.isRecording,
            isConnected: connectivityMonitor.isConnected,
            isCleanMapActive: isCleanMapActive,
            onCleanMapToggle: toggleCleanMap,
            isInsideOfflineArea: isInsideOfflineArea
        )
    }

    @ViewBuilder
    private var weatherWidgetContent: some View {
        if effectiveShowWeatherWidget {
            WeatherWidgetView(viewModel: weatherViewModel) {
                sheets.active = .weather
            }
        }
    }

    private var isInsideOfflineArea: Bool {
        guard !connectivityMonitor.isConnected else { return false }
        let coord = mapViewModel.userLocation?.coordinate ?? mapViewModel.currentCenter
        return offlineViewModel.isInsideOfflineArea(coord)
    }

    @ViewBuilder
    private var navigationOverlayLayer: some View {
        if navigationViewModel.isActive {
            NavigationOverlayView(
                navigationVM: navigationViewModel,
                userHeading: mapViewModel.userHeading,
                isConnected: connectivityMonitor.isConnected,
                onStop: showStopConfirmationAction,
                onSwitchToCompass: switchToCompassNavigation,
                onSwitchToRoute: switchToRouteNavigation,
                onToggleCamera: toggleNavigationCamera,
                onReroute: requestNavigationReroute,
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
    }

    private func showStopConfirmationAction() {
        showStopConfirmation = true
    }

    private func switchToCompassNavigation() {
        navigationViewModel.switchToCompass()
    }

    private func switchToRouteNavigation() {
        guard !navigationViewModel.isComputingRoute,
              let userLoc = mapViewModel.userLocation,
              let dest = navigationViewModel.destination else { return }
        Task {
            let success = await navigationViewModel.startRouteNavigation(
                from: userLoc.coordinate, to: dest
            )
            if !success {
                stopNavigation()
                showRouteError = true
            }
        }
    }

    private func toggleNavigationCamera() {
        navigationViewModel.toggleCameraMode()
    }

    private func requestNavigationReroute() {
        Task {
            let success = await navigationViewModel.requestReroute()
            if !success { showRouteError = true }
        }
    }

    @ViewBuilder
    private var routeComputingIndicator: some View {
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
    }

    @ViewBuilder
    private var modeToolbarLayer: some View {
        ModeToolbar(
            mode: mapMode,
            routeViewModel: routeViewModel,
            measurementViewModel: measurementViewModel,
            offlineViewModel: offlineViewModel,
            onRouteSave: { sheets.active = .routeSave },
            onDownloadArea: { sheets.active = .downloadArea }
        )
    }

    @ViewBuilder
    private var activityRecordingLayer: some View {
        if activityViewModel.isRecording {
            ActivityRecordingToolbar(
                formattedDistance: activityViewModel.formattedDistance,
                formattedDuration: activityViewModel.formattedDuration,
                formattedElevationGain: activityViewModel.formattedElevationGain,
                stackBelowNav: navigationViewModel.isActive,
                onStop: { sheets.active = .activitySave }
            )
        }
    }

    @ViewBuilder
    private var locationPrimerLayer: some View {
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
    }

    @ViewBuilder
    private var offlineWarningLayer: some View {
        if offlineViewModel.showLeftAreaWarning {
            OfflineWarningToast(viewModel: offlineViewModel)
        }
    }

    @ViewBuilder
    private var downloadCompleteLayer: some View {
        if offlineViewModel.completionMessage != nil {
            DownloadCompleteToast(viewModel: offlineViewModel)
        }
    }

    private func handleMeasurementActiveChange(_ isActive: Bool) {
        if isActive, sheets.active == .measurement {
            sheets.active = nil
        }
    }

    // MARK: - Main Layout

    private var mainLayout: some View {
        ZStack {
            mapLayer
            mapControlsLayer
            navigationOverlayLayer
            routeComputingIndicator
            modeToolbarLayer
            activityRecordingLayer
            locationPrimerLayer
            offlineWarningLayer
            downloadCompleteLayer
        }
        .tint(Color.Trakke.brand)
        .sheet(item: $sheets.active) { active in sheetContent(for: active) }
        .onChange(of: measurementViewModel.isActive) { _, isActive in
            handleMeasurementActiveChange(isActive)
        }
        .modifier(MainLayoutDialogsModifier(
            showRouteError: $showRouteError,
            showDbRecoveryAlert: $showDbRecoveryAlert,
            saveErrorBinding: saveErrorBinding,
            longPressBinding: longPressBinding,
            routeErrorMessage: navigationViewModel.routeError ?? String(localized: "navigation.routeErrorGeneric"),
            saveErrorMessage: saveErrorMessage,
            longPressButtons: longPressDialogButtons
        ))
    }

    // MARK: - Dialog Bindings & Buttons
    //
    // Bindings og knapper ekstrahert ut av mainLayout-modifier-kjeden så
    // type-checkeren kan resolve hver del isolert. Uten dette tilstander
    // den ikke å verifisere typene innen tidsbudsjett på eldre Xcode-
    // versjoner.

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { hasSaveError },
            set: { if !$0 { clearSaveErrors() } }
        )
    }

    private var hasSaveError: Bool {
        routeViewModel.saveError != nil
            || waypointViewModel.saveError != nil
            || activityViewModel.saveError != nil
    }

    private var saveErrorMessage: String {
        routeViewModel.saveError
            ?? waypointViewModel.saveError
            ?? activityViewModel.saveError
            ?? ""
    }

    private func clearSaveErrors() {
        routeViewModel.saveError = nil
        waypointViewModel.saveError = nil
        activityViewModel.saveError = nil
    }

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
            .cancel()
        ]
    }

    private func addWaypointAtLongPress() {
        guard let coord = longPressCoordinate else { return }
        waypointViewModel.startPlacing(at: coord)
        sheets.editingWaypoint = nil
        // Utsett sheet-presentasjon én runloop-tick så fullScreenCover-
        // dialog rekker å dismisses før ny sheet prøver å presentere
        // (unngår presentasjons-race).
        DispatchQueue.main.async {
            sheets.active = .waypointEdit
        }
    }

    private func navigateToLongPress() {
        guard let coord = longPressCoordinate else { return }
        navigationDestination = coord
        DispatchQueue.main.async {
            sheets.active = .navigationStart
        }
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

// MARK: - Dialog Chain Modifier
//
// Samler de fire mainLayout-dialogene i en egen ViewModifier slik at
// modifier-kjeden type-sjekkes isolert. Uten denne innpakkingen ble
// `ContentView()`-konstruksjonen for tung for SwiftUI-type-checkeren
// (>250 ms lokalt, timeout på eldre Xcode-versjoner).
private struct MainLayoutDialogsModifier: ViewModifier {
    @Binding var showRouteError: Bool
    @Binding var showDbRecoveryAlert: Bool
    let saveErrorBinding: Binding<Bool>
    let longPressBinding: Binding<Bool>
    let routeErrorMessage: String
    let saveErrorMessage: String
    let longPressButtons: [TrakkeDialogButton]

    func body(content: Content) -> some View {
        content
            .trakkeDialog(
                isPresented: $showRouteError,
                title: String(localized: "navigation.routeErrorTitle"),
                message: routeErrorMessage,
                buttons: [.primary(String(localized: "common.ok")) {}]
            )
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
                buttons: longPressButtons
            )
    }
}

#Preview {
    ContentView()
}
