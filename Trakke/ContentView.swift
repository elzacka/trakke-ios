import SwiftUI
import SwiftData
import CoreLocation

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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.showWeatherWidget) private var showWeatherWidget = false
    @AppStorage(AppStorageKeys.showCompass) private var showCompass = true
    @AppStorage(AppStorageKeys.showZoomControls) private var showZoomControls = false
    @AppStorage(AppStorageKeys.showScaleBar) private var showScaleBar = false
    @AppStorage(AppStorageKeys.enableRotation) private var enableRotation = true
    @AppStorage(AppStorageKeys.overlayTurrutebasen) private var overlayTurrutebasen = false
    @AppStorage(AppStorageKeys.overlayHillshading) private var overlayHillshading = false
    @AppStorage(AppStorageKeys.overlayNaturvernomrader) private var overlayNaturvernomrader = false
    @AppStorage(AppStorageKeys.overlayNaturskog) private var overlayNaturskog = false
    @AppStorage(AppStorageKeys.naturskogLayerType) private var naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
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
        .onChange(of: overlayTurrutebasen) { syncOverlays() }
        .onChange(of: overlayHillshading) { syncOverlays() }
        .onChange(of: overlayNaturvernomrader) { syncOverlays() }
        .onChange(of: overlayNaturskog) { syncOverlays() }
        .onChange(of: naturskogLayerType) { syncOverlays() }
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
            if scenePhase == .background, navigationViewModel.isActive {
                // Ensure idle timer is restored if system terminates
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    // MARK: - Overlay Sync

    private func syncOverlays() {
        var overlays = Set<OverlayLayer>()
        if overlayTurrutebasen { overlays.insert(.turrutebasen) }
        if overlayHillshading { overlays.insert(.hillshading) }
        if overlayNaturvernomrader { overlays.insert(.naturvernomrader) }
        if overlayNaturskog, let layer = OverlayLayer(rawValue: naturskogLayerType), layer.isNaturskog {
            overlays.insert(layer)
        }
        mapViewModel.enabledOverlays = overlays
    }

    // MARK: - Map Tap Handler

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        if measurementViewModel.isActive {
            measurementViewModel.addPoint(coordinate)
        } else if routeViewModel.isDrawing {
            routeViewModel.addPoint(coordinate)
        }
    }

    // MARK: - Long Press Handler

    private func handleMapLongPress(_ coordinate: CLLocationCoordinate2D) {
        guard !routeViewModel.isDrawing,
              !measurementViewModel.isActive,
              !offlineViewModel.isSelectingArea,
              !navigationViewModel.isActive else { return }
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
                waypoints: waypointViewModel.visibleWaypoints,
                drawingCoordinates: routeViewModel.drawingCoordinates,
                isDrawing: routeViewModel.isDrawing,
                selectionCorner1: offlineViewModel.selectionCorner1,
                selectionCorner2: offlineViewModel.selectionCorner2,
                measurementCoordinates: measurementViewModel.points,
                measurementMode: measurementViewModel.mode,
                searchPinCoordinate: mapViewModel.searchPinCoordinate,
                enabledOverlays: mapViewModel.enabledOverlays,
                showWeatherWidget: showWeatherWidget,
                enableRotation: enableRotation,
                onViewportChanged: handleViewportChanged,
                onPOISelected: { poi in
                    poiViewModel.selectPOI(poi)
                    sheets.showPOIDetail = true
                },
                onWaypointSelected: { wp in
                    waypointViewModel.selectedWaypoint = wp
                    sheets.showWaypointDetail = true
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
                onSearchTapped: { sheets.showSearchSheet = true },
                onCategoryTapped: { sheets.showCategoryPicker = true },
                onMyPlacesTapped: { sheets.showWaypointList = true },
                onWeatherTapped: { sheets.showWeatherSheet = true },
                onEmergencyTapped: { sheets.showEmergency = true },
                onMoreTapped: { sheets.showMore = true },
                enabledOverlays: mapViewModel.enabledOverlays,
                isMenuOpen: $isFABMenuOpen,
                weatherContent: Group {
                    if showWeatherWidget {
                        WeatherWidgetView(viewModel: weatherViewModel) {
                            sheets.showWeatherSheet = true
                        }
                    }
                },
                showCompass: showCompass,
                showZoomControls: showZoomControls,
                showScaleBar: showScaleBar,
                hideMenuAndZoom: routeViewModel.isDrawing || measurementViewModel.isActive || offlineViewModel.isSelectingArea || navigationViewModel.isActive || activityViewModel.isRecording,
                isConnected: connectivityMonitor.isConnected
            )

            if navigationViewModel.isActive {
                NavigationOverlayView(
                    navigationVM: navigationViewModel,
                    userHeading: mapViewModel.userHeading,
                    isConnected: connectivityMonitor.isConnected,
                    onStop: { showStopConfirmation = true },
                    onSwitchToCompass: { navigationViewModel.switchToCompass() },
                    onSwitchToRoute: {
                        guard let userLoc = mapViewModel.userLocation,
                              let dest = navigationViewModel.destination else { return }
                        Task {
                            let success = await navigationViewModel.startRouteNavigation(
                                from: userLoc.coordinate, to: dest
                            )
                            if !success { stopNavigation(); showRouteError = true }
                        }
                    },
                    onToggleCamera: { navigationViewModel.toggleCameraMode() }
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
                        Text(String(localized: "navigation.computing"))
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

            if routeViewModel.isDrawing {
                DrawingToolbar(
                    pointCount: routeViewModel.drawingCoordinates.count,
                    formattedDistance: routeViewModel.formattedDrawingDistance,
                    onCancel: { routeViewModel.cancelDrawing() },
                    onUndo: { routeViewModel.undoLastPoint() },
                    onDone: { sheets.showRouteSave = true }
                )
            }

            if measurementViewModel.isActive {
                MeasurementToolbar(
                    mode: measurementViewModel.mode ?? .distance,
                    formattedResult: measurementViewModel.formattedResult,
                    hasPoints: !measurementViewModel.points.isEmpty,
                    onCancel: { measurementViewModel.stop() },
                    onUndo: { measurementViewModel.undoLastPoint() },
                    onClear: { measurementViewModel.clearAll() }
                )
            }

            if offlineViewModel.isSelectingArea {
                SelectionToolbar(
                    hasValidSelection: offlineViewModel.hasValidSelection,
                    estimatedTileCount: offlineViewModel.estimatedTileCount,
                    estimatedSize: offlineViewModel.estimatedSize,
                    onCancel: { offlineViewModel.cancelSelection() },
                    onDone: { sheets.showDownloadArea = true }
                )
            }

            if activityViewModel.isRecording {
                ActivityRecordingToolbar(
                    formattedDistance: activityViewModel.formattedDistance,
                    formattedDuration: activityViewModel.formattedDuration,
                    formattedElevationGain: activityViewModel.formattedElevationGain,
                    onStop: { sheets.showActivitySave = true }
                )
            }

            if mapViewModel.showLocationPrimer {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        mapViewModel.dismissLocationPrimer()
                    }

                LocationPrimerView(
                    onAllow: { mapViewModel.confirmLocationPermission() },
                    onDismiss: { mapViewModel.dismissLocationPrimer() }
                )
                .transition(.opacity)
            }
        }
        .tint(Color.Trakke.brand)
        .sheet(isPresented: $sheets.showSearchSheet) {
            SearchSheet(
                viewModel: searchViewModel,
                onResultSelected: { result in
                    mapViewModel.searchPinCoordinate = result.coordinate
                    mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sheets.showCategoryPicker) {
            CategoryPickerSheet(viewModel: poiViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sheets.showPOIDetail) {
            if let poi = poiViewModel.selectedPOI {
                POIDetailSheet(
                    poi: poi,
                    onNavigate: { coordinate in
                        sheets.showPOIDetail = false
                        navigationDestination = coordinate
                        sheets.showNavigationStart = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $sheets.showRouteList) {
            RouteListSheet(
                viewModel: routeViewModel,
                onRouteSelected: { route in
                    routeViewModel.selectRoute(route)
                    sheets.showRouteDetail = true
                },
                onNewRoute: {
                    routeViewModel.startDrawing()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showRouteDetail) {
            if let route = routeViewModel.selectedRoute {
                RouteDetailSheet(
                    viewModel: routeViewModel,
                    route: route,
                    onNavigate: { route in
                        sheets.showRouteDetail = false
                        startFollowingRoute(route)
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $sheets.showOfflineManager) {
            DownloadManagerSheet(
                viewModel: offlineViewModel,
                onNewDownload: {
                    offlineViewModel.startSelection(
                        center: mapViewModel.currentCenter,
                        zoom: mapViewModel.currentZoom
                    )
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showDownloadArea) {
            DownloadAreaSheet(viewModel: offlineViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showWeatherSheet) {
            WeatherSheet(viewModel: weatherViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showMeasurementSheet) {
            MeasurementSheet(viewModel: measurementViewModel)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: measurementViewModel.isActive) { _, isActive in
            if isActive { sheets.showMeasurementSheet = false }
        }
        .sheet(isPresented: $sheets.showPreferences) {
            PreferencesSheet(mapViewModel: mapViewModel, knowledgeViewModel: knowledgeViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showInfo) {
            InfoSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showWaypointList) {
            WaypointListSheet(
                viewModel: waypointViewModel,
                onWaypointSelected: { wp in
                    waypointViewModel.selectedWaypoint = wp
                    sheets.showWaypointDetail = true
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showWaypointDetail) {
            if let wp = waypointViewModel.selectedWaypoint {
                WaypointDetailSheet(
                    viewModel: waypointViewModel,
                    waypoint: wp,
                    onEdit: { waypoint in
                        sheets.showWaypointDetail = false
                        sheets.editingWaypoint = waypoint
                        sheets.showWaypointEdit = true
                    },
                    onNavigate: { coordinate in
                        sheets.showWaypointDetail = false
                        navigationDestination = coordinate
                        sheets.showNavigationStart = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $sheets.showWaypointEdit) {
            WaypointEditSheet(
                viewModel: waypointViewModel,
                editingWaypoint: sheets.editingWaypoint
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sheets.showRouteSave) {
            RouteSaveSheet(viewModel: routeViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sheets.showNavigationStart) {
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
        }
        .sheet(isPresented: $sheets.showEmergency, onDismiss: { sosViewModel.deactivate() }) {
            EmergencySheet(
                userLocation: mapViewModel.userLocation,
                sosViewModel: sosViewModel
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sheets.showActivityList) {
            ActivityListSheet(
                viewModel: activityViewModel,
                onActivitySelected: { activity in
                    activityViewModel.selectedActivity = activity
                    sheets.showActivityDetail = true
                },
                onStartRecording: {
                    startActivityRecording()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showActivityDetail) {
            if let activity = activityViewModel.selectedActivity {
                ActivityDetailSheet(
                    viewModel: activityViewModel,
                    activity: activity,
                    onRetrace: { coordinate in
                        sheets.showActivityDetail = false
                        navigationDestination = coordinate
                        sheets.showNavigationStart = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $sheets.showActivitySave) {
            ActivitySaveSheet(viewModel: activityViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sheets.showKnowledge) {
            KnowledgeSheet(viewModel: knowledgeViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showMore) {
            MoreSheet(
                knowledgeViewModel: knowledgeViewModel,
                routeViewModel: routeViewModel,
                activityViewModel: activityViewModel,
                mapViewModel: mapViewModel,
                onMeasurementTapped: { sheets.showMeasurementSheet = true },
                onOfflineTapped: {
                    if offlineViewModel.packs.isEmpty {
                        offlineViewModel.startSelection(
                            center: mapViewModel.currentCenter,
                            zoom: mapViewModel.currentZoom
                        )
                    } else {
                        sheets.showOfflineManager = true
                    }
                },
                onRouteSelected: { route in
                    routeViewModel.selectRoute(route)
                    sheets.showRouteDetail = true
                },
                onNewRoute: {
                    routeViewModel.startDrawing()
                },
                onActivitySelected: { activity in
                    activityViewModel.selectedActivity = activity
                    sheets.showActivityDetail = true
                },
                onStartRecording: {
                    startActivityRecording()
                }
            )
            .presentationDetents([.medium, .large])
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
                    sheets.showWaypointEdit = true
                }
            }
            Button(String(localized: "navigation.navigateHere")) {
                if let coord = longPressCoordinate {
                    navigationDestination = coord
                    sheets.showNavigationStart = true
                }
            }
        }
    }

    // MARK: - Navigation
    // See ContentView+Navigation.swift for navigation method implementations.
}

#Preview {
    ContentView()
}
