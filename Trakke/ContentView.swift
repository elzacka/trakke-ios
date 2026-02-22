import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @State private var mapViewModel = MapViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var poiViewModel = POIViewModel()
    @State private var routeViewModel = RouteViewModel()
    @State private var waypointViewModel = WaypointViewModel()
    @State private var offlineViewModel = OfflineViewModel()
    @State private var weatherViewModel = WeatherViewModel()
    @State private var measurementViewModel = MeasurementViewModel()
    @State private var navigationViewModel = NavigationViewModel()
    @State private var sheets = SheetCoordinator()
    @State private var connectivityMonitor = ConnectivityMonitor()
    @State private var navigationDestination: CLLocationCoordinate2D?
    @State private var showLongPressOptions = false
    @State private var longPressCoordinate: CLLocationCoordinate2D?
    @State private var navigatingRouteId: String?
    @State private var showRouteError = false
    @State private var showStopConfirmation = false
    @State private var showDbRecoveryAlert = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("showWeatherWidget") private var showWeatherWidget = false
    @AppStorage("showCompass") private var showCompass = true
    @AppStorage("showZoomControls") private var showZoomControls = false
    @AppStorage("showScaleBar") private var showScaleBar = false
    @AppStorage("enableRotation") private var enableRotation = true
    @AppStorage("overlayTurrutebasen") private var overlayTurrutebasen = false
    @AppStorage("overlayNaturskog") private var overlayNaturskog = false
    @AppStorage("naturskogLayerType") private var naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        mainLayout
        .onAppear {
            routeViewModel.setModelContext(modelContext)
            routeViewModel.loadRoutes()
            waypointViewModel.setModelContext(modelContext)
            waypointViewModel.loadWaypoints()
            offlineViewModel.startObserving()
            connectivityMonitor.start()
            syncOverlays()
            if UserDefaults.standard.bool(forKey: "dbRecoveryOccurred") {
                UserDefaults.standard.removeObject(forKey: "dbRecoveryOccurred")
                showDbRecoveryAlert = true
            }
        }
        .onChange(of: overlayTurrutebasen) { syncOverlays() }
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
                onRouteTapped: {
                    sheets.showRouteList = true
                },
                onMyPlacesTapped: { sheets.showWaypointList = true },
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
                onWeatherTapped: { sheets.showWeatherSheet = true },
                onMeasurementTapped: { sheets.showMeasurementSheet = true },
                onSettingsTapped: { sheets.showPreferences = true },
                onInfoTapped: { sheets.showInfo = true },
                enabledOverlays: mapViewModel.enabledOverlays,
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
                hideMenuAndZoom: routeViewModel.isDrawing || measurementViewModel.isActive || offlineViewModel.isSelectingArea || navigationViewModel.isActive,
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
                    HStack(spacing: 8) {
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
            SearchSheet(viewModel: searchViewModel) { result in
                mapViewModel.searchPinCoordinate = result.coordinate
                mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $sheets.showCategoryPicker) {
            CategoryPickerSheet(viewModel: poiViewModel)
                .presentationDetents([.medium])
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
        }
        .onChange(of: measurementViewModel.isActive) { _, isActive in
            if isActive { sheets.showMeasurementSheet = false }
        }
        .sheet(isPresented: $sheets.showPreferences) {
            PreferencesSheet(mapViewModel: mapViewModel)
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
        }
        .sheet(isPresented: $sheets.showRouteSave) {
            RouteSaveSheet(viewModel: routeViewModel)
                .presentationDetents([.medium])
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
            }
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
                get: { routeViewModel.saveError != nil || waypointViewModel.saveError != nil },
                set: { if !$0 { routeViewModel.saveError = nil; waypointViewModel.saveError = nil } }
            )
        ) {
            Button(String(localized: "common.ok")) {}
        }
        .confirmationDialog(
            String(localized: "map.longPressTitle"),
            isPresented: $showLongPressOptions,
            titleVisibility: .visible
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

    private func startRouteNavigation(to destination: CLLocationCoordinate2D) {
        guard let userLocation = mapViewModel.userLocation else { return }
        mapViewModel.startNavigation()
        mapViewModel.onLocationUpdate = { [weak navigationViewModel] location in
            Task { @MainActor in
                await navigationViewModel?.processLocationUpdate(location)
            }
        }
        Task {
            let success = await navigationViewModel.startRouteNavigation(
                from: userLocation.coordinate, to: destination
            )
            if success {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                // Route computation failed -- clean up half-started state
                mapViewModel.stopNavigation()
                showRouteError = true
            }
        }
    }

    private func startCompassNavigation(to destination: CLLocationCoordinate2D) {
        mapViewModel.startNavigation()
        mapViewModel.onLocationUpdate = { [weak navigationViewModel] location in
            Task { @MainActor in
                await navigationViewModel?.processLocationUpdate(location)
            }
        }
        navigationViewModel.startCompassNavigation(to: destination)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func startFollowingRoute(_ route: Route) {
        navigatingRouteId = route.id
        mapViewModel.startNavigation()
        mapViewModel.onLocationUpdate = { [weak navigationViewModel] location in
            Task { @MainActor in
                await navigationViewModel?.processLocationUpdate(location)
            }
        }
        navigationViewModel.startFollowingRoute(
            route: route,
            elevationProfile: routeViewModel.elevationProfile
        )
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func stopNavigation() {
        navigationViewModel.stopNavigation()
        mapViewModel.stopNavigation()
        navigatingRouteId = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }


}

#Preview {
    ContentView()
}
