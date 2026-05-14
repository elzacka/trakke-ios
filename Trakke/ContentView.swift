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
    @State var mapViewModel = MapViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var poiViewModel = POIViewModel()
    @State var routeViewModel = RouteViewModel()
    @State private var waypointViewModel = WaypointViewModel()
    @State private var offlineViewModel = OfflineViewModel()
    @State private var weatherViewModel = WeatherViewModel()
    @State private var measurementViewModel = MeasurementViewModel()
    @State var navigationViewModel = NavigationViewModel()
    @State private var sosViewModel = SOSViewModel()
    @State var activityViewModel = ActivityViewModel()
    @State private var knowledgeViewModel = KnowledgeViewModel()
    @State private var sheets = SheetCoordinator()
    @State private var connectivityMonitor = ConnectivityMonitor()
    @State private var navigationDestination: CLLocationCoordinate2D?
    @State private var showLongPressOptions = false
    @State private var isFABMenuOpen = false
    @State private var longPressCoordinate: CLLocationCoordinate2D?
    @State var navigatingRouteId: String?
    @State var showRouteError = false
    @State private var showStopConfirmation = false
    @State private var showDbRecoveryAlert = false
    @State private var isCleanMapActive = false
    private let haptics = HapticFeedbackService()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppStorageKeys.showWeatherWidget) private var showWeatherWidget = false
    @AppStorage(AppStorageKeys.showCompass) private var showCompass = false
    @AppStorage(AppStorageKeys.showZoomControls) private var showZoomControls = false
    @AppStorage(AppStorageKeys.showScaleBar) private var showScaleBar = false
    @AppStorage(AppStorageKeys.enableRotation) private var enableRotation = true
    @AppStorage(AppStorageKeys.overlayTurrutebasen) private var overlayTurrutebasen = false
    @AppStorage(AppStorageKeys.overlayHillshading) private var overlayHillshading = false
    @AppStorage(AppStorageKeys.overlayNaturvernomrader) private var overlayNaturvernomrader = false
    @AppStorage(AppStorageKeys.overlayNaturskog) private var overlayNaturskog = false
    @AppStorage(AppStorageKeys.overlayBratthetskart) private var overlayBratthetskart = false
    @AppStorage(AppStorageKeys.overlayUtmRunenett) private var overlayUtmRunenett = false
    @AppStorage(AppStorageKeys.naturskogLayerType) private var naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
    private var overlayFingerprint: String {
        "\(overlayTurrutebasen)\(overlayHillshading)\(overlayNaturvernomrader)\(overlayNaturskog)\(overlayBratthetskart)\(overlayUtmRunenett)\(naturskogLayerType)"
    }
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
            syncOverlays()
            if UserDefaults.standard.bool(forKey: AppStorageKeys.dbRecoveryOccurred) {
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.dbRecoveryOccurred)
                showDbRecoveryAlert = true
            }
        }
        .onChange(of: overlayFingerprint) { syncOverlays() }
        .onDisappear {
            offlineViewModel.stopObserving()
            connectivityMonitor.stop()
        }
        .onChange(of: searchViewModel.query) {
            mapViewModel.searchPinCoordinate = nil
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
        .onOpenURL { url in
            // Files shared to Tråkke via "Open with" or AirDrop can contain waypoints,
            // tracks (which may be either planned routes or recorded activities), or
            // any mix (GeoJSON). Prefer Activity over Route when track points carry
            // timestamps — that's the strongest signal a file is a recorded trip.
            var activityCount = 0
            var routeCount = 0
            var waypointCount = 0
            switch url.pathExtension.lowercased() {
            case "geojson", "json":
                // Parse GeoJSON once and dispatch to each view model. Previously each
                // VM parsed the same file independently, decoding the JSON 3 times.
                do {
                    let result = try GeoJSONImportService.parse(from: url)
                    let filename = url.importedItemName
                    activityCount = activityViewModel.insertImported(result.activities, filename: filename)
                    if activityCount == 0 {
                        routeCount = routeViewModel.insertImported(result.routes, filename: filename)
                    }
                    waypointCount = waypointViewModel.insertImported(result.waypoints, filename: filename)
                } catch {
                    routeViewModel.importMessage = String(localized: "routes.importError")
                }
            case "gpx":
                // GPX parsers each scan for a different element type, so per-VM
                // calls are kept here. XMLParser is streaming and cheap; the 3-pass
                // cost is negligible compared to the GeoJSON case.
                activityCount = activityViewModel.importFile(from: url)
                routeCount = (activityCount > 0) ? 0 : routeViewModel.importFile(from: url)
                waypointCount = waypointViewModel.importFile(from: url)
            default:
                break
            }
            sheets.dismissAll()
            // Multiple types in one file: open the unified MyStuff sheet so the
            // user can navigate between lists. Otherwise jump directly to the
            // relevant list.
            let typesImported = (activityCount > 0 ? 1 : 0)
                + (routeCount > 0 ? 1 : 0)
                + (waypointCount > 0 ? 1 : 0)
            if typesImported > 1 {
                sheets.active = .merSheet
            } else if activityCount > 0 {
                sheets.active = .activityList
            } else if routeCount > 0 {
                sheets.active = .routeList
            } else if waypointCount > 0 {
                sheets.active = .waypointList
            }
        }
    }

    // MARK: - Overlay Sync

    private func syncOverlays() {
        var overlays = Set<OverlayLayer>()
        if overlayTurrutebasen { overlays.insert(.turrutebasen) }
        if overlayHillshading { overlays.insert(.hillshading) }
        if overlayNaturvernomrader { overlays.insert(.naturvernomrader) }
        if overlayBratthetskart { overlays.insert(.bratthetskart) }
        if overlayUtmRunenett { overlays.insert(.utmRunenett) }
        if overlayNaturskog, let layer = OverlayLayer(rawValue: naturskogLayerType), layer.isNaturskog {
            overlays.insert(layer)
        }
        mapViewModel.enabledOverlays = overlays
    }

    // MARK: - Clean Map

    private var effectiveShowCompass: Bool { isCleanMapActive ? false : showCompass }
    private var effectiveShowZoomControls: Bool { isCleanMapActive ? false : showZoomControls }
    private var effectiveShowScaleBar: Bool { isCleanMapActive ? false : showScaleBar }
    private var effectiveShowWeatherWidget: Bool { isCleanMapActive ? false : showWeatherWidget }
    private var effectiveOverlays: Set<OverlayLayer> { isCleanMapActive ? [] : mapViewModel.enabledOverlays }

    private func toggleCleanMap() {
        haptics.success()
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
        showLongPressOptions = true
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
                offlinePackBounds: connectivityMonitor.isConnected ? [] : offlineViewModel.packs.filter(\.progress.isComplete).map(\.bounds),
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
                onSearchTapped: { sheets.active = .search },
                onCategoryTapped: { sheets.active = .categoryPicker },
                onMerTapped: { sheets.active = .merSheet },
                onWeatherTapped: { sheets.active = .weather },
                onEmergencyTapped: { sheets.active = .emergency },
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
                    onWeatherTapped: { sheets.active = .weather },
                    onMerTapped: { sheets.active = .merSheet }
                )
                .confirmationDialog(
                    String(localized: "navigation.stopConfirmTitle"),
                    isPresented: $showStopConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "navigation.stop"), role: .destructive) {
                        stopNavigation()
                    }
                }
            }

            if navigationViewModel.isComputingRoute {
                VStack {
                    Spacer()
                    HStack(spacing: .Trakke.sm) {
                        ProgressView()
                        Text(String(localized: "navigation.computingRoute"))
                            .font(Font.Trakke.bodyRegular)
                    }
                    .padding(.horizontal, .Trakke.lg)
                    .padding(.vertical, .Trakke.sm)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, .Trakke.lg)
                }
                .safeAreaPadding(.bottom)
            }

            modeToolbar

            if activityViewModel.isRecording {
                ActivityRecordingToolbar(
                    formattedDistance: activityViewModel.formattedDistance,
                    formattedDuration: activityViewModel.formattedDuration,
                    formattedElevationGain: activityViewModel.formattedElevationGain,
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
                offlineWarningToast
            }

            // Download completion toast
            if offlineViewModel.completionMessage != nil {
                downloadCompleteToast
            }
        }
        .tint(Color.Trakke.brand)
        .sheet(item: $sheets.active) { active in
            sheetContent(for: active)
        }
        .onChange(of: measurementViewModel.isActive) { _, isActive in
            if isActive, sheets.active == .measurement { sheets.active = nil }
        }
        .alert(
            String(localized: "navigation.routeErrorTitle"),
            isPresented: $showRouteError
        ) {
            Button(String(localized: "common.ok")) {}
        } message: {
            Text(navigationViewModel.routeError ?? String(localized: "navigation.routeErrorGeneric"))
        }
        .alert(
            String(localized: "settings.dbRecovery.title"),
            isPresented: $showDbRecoveryAlert
        ) {
            Button(String(localized: "common.ok")) {}
        } message: {
            Text(String(localized: "settings.dbRecovery.message"))
        }
        .alert(
            String(localized: "error.saveFailed"),
            isPresented: Binding(
                get: { routeViewModel.saveError != nil || waypointViewModel.saveError != nil || activityViewModel.saveError != nil },
                set: { if !$0 { routeViewModel.saveError = nil; waypointViewModel.saveError = nil; activityViewModel.saveError = nil } }
            )
        ) {
            Button(String(localized: "common.ok")) {}
        } message: {
            Text(routeViewModel.saveError ?? waypointViewModel.saveError ?? activityViewModel.saveError ?? "")
        }
        .confirmationDialog(
            "",
            isPresented: $showLongPressOptions,
            titleVisibility: .hidden
        ) {
            Button(String(localized: "waypoints.addWaypoint")) {
                if let coord = longPressCoordinate {
                    waypointViewModel.startPlacing(at: coord)
                    sheets.editingWaypoint = nil
                    sheets.active = .waypointEdit
                }
            }
            Button(String(localized: "navigation.navigateHere")) {
                if let coord = longPressCoordinate {
                    navigationDestination = coord
                    sheets.active = .navigationStart
                }
            }
        }
    }

    // MARK: - Mode Toolbar

    @ViewBuilder
    private var modeToolbar: some View {
        switch mapMode {
        case .drawing:
            DrawingToolbar(
                pointCount: routeViewModel.drawingCoordinates.count,
                formattedDistance: routeViewModel.formattedDrawingDistance,
                onCancel: { routeViewModel.cancelDrawing() },
                onUndo: { routeViewModel.undoLastPoint() },
                onDone: { sheets.active = .routeSave }
            )
        case .measuring:
            MeasurementToolbar(
                mode: measurementViewModel.mode ?? .distance,
                formattedResult: measurementViewModel.formattedResult,
                hasPoints: !measurementViewModel.points.isEmpty,
                onCancel: { measurementViewModel.stop() },
                onUndo: { measurementViewModel.undoLastPoint() },
                onClear: { measurementViewModel.clearAll() }
            )
        case .selecting:
            SelectionToolbar(
                hasValidSelection: offlineViewModel.hasValidSelection,
                estimatedTileCount: offlineViewModel.estimatedTileCount,
                estimatedSize: offlineViewModel.estimatedSize,
                onCancel: { offlineViewModel.cancelSelection() },
                onDone: { sheets.active = .downloadArea }
            )
        case .idle, .navigating:
            EmptyView()
        }
    }

    // MARK: - Sheet Routing

    @ViewBuilder
    private func sheetContent(for active: ActiveSheet) -> some View {
        switch active {
        case .search:
            SearchSheet(
                viewModel: searchViewModel,
                onResultSelected: { result in
                    mapViewModel.searchPinCoordinate = result.coordinate
                    mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .categoryPicker:
            CategoryPickerSheet(viewModel: poiViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)

        case .poiDetail:
            if let poi = poiViewModel.selectedPOI {
                POIDetailSheet(
                    poi: poi,
                    onNavigate: { coordinate in
                        navigationDestination = coordinate
                        sheets.active = .navigationStart
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }

        case .routeList:
            RouteListSheet(
                viewModel: routeViewModel,
                onRouteSelected: { route in
                    sheets.active = nil
                    startFollowingRoute(route)
                },
                onNewRoute: {
                    routeViewModel.startDrawing()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .routeSave:
            RouteSaveSheet(viewModel: routeViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)

        case .merSheet:
            MerSheet(
                routeViewModel: routeViewModel,
                waypointViewModel: waypointViewModel,
                activityViewModel: activityViewModel,
                knowledgeViewModel: knowledgeViewModel,
                mapViewModel: mapViewModel,
                offlineViewModel: offlineViewModel,
                onRouteSelected: { route in
                    startFollowingRoute(route)
                },
                onNewRoute: {
                    routeViewModel.startDrawing()
                },
                onWaypointEdit: { wp in
                    sheets.editingWaypoint = wp
                    sheets.active = .waypointEdit
                },
                onWaypointNavigate: { coordinate in
                    navigationDestination = coordinate
                    sheets.active = .navigationStart
                },
                onActivityRetrace: { coordinate in
                    navigationDestination = coordinate
                    sheets.active = .navigationStart
                },
                onActivityFollow: { activity in
                    followActivity(activity)
                },
                onStartRecording: {
                    startActivityRecording()
                },
                onMeasurementTapped: { sheets.active = .measurement },
                onOfflineTapped: { sheets.active = .offlineSetup },
                onDeleteAllData: clearAllServiceCaches
            )

        case .waypointList:
            WaypointListSheet(
                viewModel: waypointViewModel,
                onWaypointSelected: { _ in },
                onWaypointEdit: { wp in
                    sheets.editingWaypoint = wp
                    sheets.active = .waypointEdit
                },
                onWaypointNavigate: { coordinate in
                    navigationDestination = coordinate
                    sheets.active = .navigationStart
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .waypointDetail:
            if let wp = waypointViewModel.selectedWaypoint {
                WaypointDetailSheet(
                    viewModel: waypointViewModel,
                    waypoint: wp,
                    onEdit: { waypoint in
                        sheets.editingWaypoint = waypoint
                        sheets.active = .waypointEdit
                    },
                    onNavigate: { coordinate in
                        navigationDestination = coordinate
                        sheets.active = .navigationStart
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }

        case .waypointEdit:
            WaypointEditSheet(
                viewModel: waypointViewModel,
                editingWaypoint: sheets.editingWaypoint
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)

        case .offlineManager:
            DownloadManagerSheet(
                viewModel: offlineViewModel,
                onNewDownload: {
                    sheets.active = .offlineSetup
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .downloadArea:
            DownloadAreaSheet(viewModel: offlineViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .offlineSetup:
            OfflineSetupSheet(
                viewModel: offlineViewModel,
                onCustom: {
                    offlineViewModel.startSelection(
                        center: mapViewModel.currentCenter,
                        zoom: mapViewModel.currentZoom
                    )
                }
            )

        case .weather:
            WeatherSheet(viewModel: weatherViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)

        case .measurement:
            MeasurementSheet(viewModel: measurementViewModel)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)

        case .navigationStart:
            if let dest = navigationDestination {
                NavigationStartSheet(
                    destination: dest,
                    userLocation: mapViewModel.userLocation,
                    isConnected: connectivityMonitor.isConnected,
                    onRouteNavigation: { startRouteNavigation(to: dest) },
                    onCompassNavigation: { startCompassNavigation(to: dest) }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }

        case .emergency:
            EmergencySheet(
                userLocation: mapViewModel.userLocation,
                sosViewModel: sosViewModel
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onDisappear { sosViewModel.deactivate() }

        case .activityList:
            ActivityListSheet(
                viewModel: activityViewModel,
                routeViewModel: routeViewModel,
                onActivitySelected: { _ in },
                onStartRecording: {
                    startActivityRecording()
                },
                onRetrace: { coordinate in
                    navigationDestination = coordinate
                    sheets.active = .navigationStart
                },
                onFollowAgain: { activity in
                    sheets.active = nil
                    followActivity(activity)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .activitySave:
            ActivitySaveSheet(viewModel: activityViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

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

    // MARK: - Toast Views

    private var offlineWarningToast: some View {
        Text(String(localized: "offline.leftArea"))
            .font(Font.Trakke.caption)
            .foregroundStyle(Color.Trakke.textInverse)
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(Color.Trakke.warning)
            .clipShape(Capsule())
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 80)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation(reduceMotion ? nil : .default) {
                    offlineViewModel.showLeftAreaWarning = false
                }
            }
    }

    private var downloadCompleteToast: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "checkmark.circle.fill")
            Text(String(localized: "offline.downloadComplete \(offlineViewModel.completionMessage ?? "")"))
                .font(Font.Trakke.caption)
        }
        .foregroundStyle(Color.Trakke.textInverse)
        .padding(.horizontal, .Trakke.lg)
        .padding(.vertical, .Trakke.sm)
        .background(Color.Trakke.brand)
        .clipShape(Capsule())
        .trakkeControlShadow()
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 80)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(reduceMotion ? nil : .default) {
                offlineViewModel.completionMessage = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
