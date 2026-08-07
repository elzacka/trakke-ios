import SwiftUI
import CoreLocation

/// Hovedkartet med alle overlays. Tar `AppCoordinator`, `SheetCoordinator`
/// og `ConnectivityMonitor` som referanser, og fire `@Binding`-felter for
/// view-state som fortsatt eies av `ContentView`.
///
/// Var tidligere `mainLayout: some View { ZStack { ... } }` inne i
/// `ContentView` med ni `@ViewBuilder`-properties. Ekstrahert som egen
/// struct slik at `ContentView`-body type-sjekkes uavhengig av kart-
/// kompleksiteten.
struct MapScreen: View {
    let coordinator: AppCoordinator
    let sheets: SheetCoordinator
    let connectivityMonitor: ConnectivityMonitor

    @Binding var isFABMenuOpen: Bool
    @Binding var isCleanMapActive: Bool
    @Binding var longPressCoordinate: CLLocationCoordinate2D?

    @AppStorage(AppStorageKeys.showWeatherWidget) private var showWeatherWidget = false
    @AppStorage(AppStorageKeys.showCompass) private var showCompass = false
    @AppStorage(AppStorageKeys.showZoomControls) private var showZoomControls = false
    @AppStorage(AppStorageKeys.showScaleBar) private var showScaleBar = false
    @AppStorage(AppStorageKeys.showZoomLevel) private var showZoomLevel = false
    @AppStorage(AppStorageKeys.enableRotation) private var enableRotation = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Aliaser så body-uttrykk holder seg lesbare og type-checker resolver
    // hver coordinator-tilgang isolert.
    private var mapViewModel: MapViewModel { coordinator.mapViewModel }
    private var poiViewModel: POIViewModel { coordinator.poiViewModel }
    private var routeViewModel: RouteViewModel { coordinator.routeViewModel }
    private var waypointViewModel: WaypointViewModel { coordinator.waypointViewModel }
    private var offlineViewModel: OfflineViewModel { coordinator.offlineViewModel }
    private var weatherViewModel: WeatherViewModel { coordinator.weatherViewModel }
    private var measurementViewModel: MeasurementViewModel { coordinator.measurementViewModel }
    private var navigationViewModel: NavigationViewModel { coordinator.navigationViewModel }
    private var activityViewModel: ActivityViewModel { coordinator.activityViewModel }

    var body: some View {
        ZStack {
            mapLayer
            mapControlsLayer
            navigationOverlayLayer
            modeToolbarLayer
            activityRecordingLayer
            locationPrimerLayer
            offlineWarningLayer
            downloadBackgroundWarningLayer
            downloadCompleteLayer
        }
    }

    // MARK: - Clean Map

    private var cameraFollowMode: MapCameraFollowMode {
        MapCameraFollowMode.current(
            isCameraDetached: mapViewModel.isCameraDetached,
            isNavigating: navigationViewModel.isActive,
            navigationCameraMode: navigationViewModel.cameraMode,
            isTrackingUser: mapViewModel.isTrackingUser,
            isHeadingUp: mapViewModel.isHeadingUp
        )
    }

    /// Knappen er ikke lenger bare et kompass – den er lokasjons- og
    /// følgekontrollen, og eneste sted modusen leses av. Den må derfor vises
    /// så snart kameraet gjør noe: følger deg, eller er koblet fra fordi du
    /// dro i kartet. Uten dette kunne du med kompasset avslått i Visning bare
    /// se modus «fritt», aldri nå «retning opp», og aldri se at kartet følger
    /// deg.
    ///
    /// Det eneste tilfellet som fortsatt respekterer preferansen er
    /// utgangstilstanden: kartet har aldri fulgt deg, og du har ikke flyttet
    /// det. Da er det ingenting å melde. Rent kart går foran alt – der er
    /// poenget at kontrollene er borte.
    private var effectiveShowCompass: Bool {
        guard !isCleanMapActive else { return false }
        if showCompass || navigationViewModel.isActive { return true }
        return cameraFollowMode != .free || mapViewModel.isCameraDetached
    }
    private var effectiveShowZoomControls: Bool { isCleanMapActive ? false : showZoomControls }
    private var effectiveShowScaleBar: Bool { isCleanMapActive ? false : showScaleBar }
    private var effectiveShowZoomLevel: Bool { isCleanMapActive ? false : showZoomLevel }
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

    // MARK: - Handlers

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        switch mapMode {
        case .measuring: measurementViewModel.addPoint(coordinate)
        case .drawing: routeViewModel.addPoint(coordinate)
        case .idle:
            // Trykk på kartet lukker eventuell åpen sheet eller FAB-meny.
            // Krever at sheetene har `.presentationBackgroundInteraction
            // (.enabled(upThrough: .medium))` slik at tap-en faktisk når
            // gjennom til kartet.
            // Ikke lukk SOS-sheet ved kart-tap – en aktiv nødmelding
            // må aldri avbrytes av et utilsiktet trykk.
            guard !coordinator.sosViewModel.isActive else { return }
            if sheets.active != nil {
                sheets.active = nil
            } else if isFABMenuOpen {
                isFABMenuOpen = false
            }
        case .selecting, .navigating: break
        }
    }

    private func handleMapLongPress(_ coordinate: CLLocationCoordinate2D) {
        guard mapMode == .idle else { return }
        longPressCoordinate = coordinate
    }

    private func handleViewportChanged(bounds: ViewportBounds, zoom: Double) {
        poiViewModel.viewportChanged(bounds: bounds, zoom: zoom)

        // Weather defaults to off. Only fetch when the widget is visible or
        // the weather sheet is open -- otherwise every map pan wakes the radio
        // for data nobody is looking at, draining battery in marginal coverage.
        guard showWeatherWidget || sheets.active == .weather else { return }

        // Fetch weather for map center
        let center = CLLocationCoordinate2D(
            latitude: (bounds.north + bounds.south) / 2,
            longitude: (bounds.east + bounds.west) / 2
        )
        weatherViewModel.fetchForecast(for: center)
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

    // MARK: - Map Layer
    //
    // TrakkeMapView har 30+ argumenter; å la den stå inline i ZStack
    // belastet body-uttrykket over CI-budsjettet. Holdes i egen
    // @ViewBuilder-property.

    @ViewBuilder
    private var mapLayer: some View {
        TrakkeMapView(
            viewModel: mapViewModel,
            pois: poiViewModel.pois,
            routes: routeViewModel.visibleRoutes,
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
            isNavigating: navigationViewModel.isActive,
            navigationCameraMode: navigationViewModel.cameraMode,
            userHeading: mapViewModel.userHeading,
            compassDestination: navigationViewModel.destination
        )
        .ignoresSafeArea()
    }

    private var offlinePackBounds: [(south: Double, west: Double, north: Double, east: Double)] {
        connectivityMonitor.isConnected ? [] : offlineViewModel.completedPackBounds
    }

    // MARK: - Controls

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
            showZoomLevel: effectiveShowZoomLevel,
            hideMenuAndZoom: mapMode != .idle || activityViewModel.isRecording,
            isConnected: connectivityMonitor.isConnected,
            isCleanMapActive: isCleanMapActive,
            onCleanMapToggle: toggleCleanMap,
            isInsideOfflineArea: isInsideOfflineArea,
            isNavigating: navigationViewModel.isActive,
            navigationCameraMode: navigationViewModel.cameraMode,
            onToggleCameraMode: coordinator.toggleNavigationCamera
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

    // MARK: - Navigation overlay

    @ViewBuilder
    private var navigationOverlayLayer: some View {
        if navigationViewModel.isActive {
            NavigationOverlayView(
                navigationVM: navigationViewModel,
                userHeading: mapViewModel.userHeading,
                headingIsReliable: mapViewModel.headingIsReliable,
                onStop: { coordinator.showStopConfirmation = true }
            )
            .trakkeDialog(
                isPresented: stopConfirmationBinding,
                title: String(localized: "navigation.stopConfirmTitle"),
                primary: .destructive(String(localized: "common.yes")) {
                    coordinator.stopNavigation()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
        }
    }

    private var stopConfirmationBinding: Binding<Bool> {
        Binding(
            get: { coordinator.showStopConfirmation },
            set: { coordinator.showStopConfirmation = $0 }
        )
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
    private var downloadBackgroundWarningLayer: some View {
        if offlineViewModel.showDownloadBackgroundWarning {
            DownloadBackgroundWarningToast(viewModel: offlineViewModel)
        }
    }

    @ViewBuilder
    private var downloadCompleteLayer: some View {
        if offlineViewModel.completionMessage != nil {
            DownloadCompleteToast(viewModel: offlineViewModel)
        }
    }
}
