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
    @State private var sheets = SheetCoordinator()
    @State private var connectivityMonitor = ConnectivityMonitor()
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
              !offlineViewModel.isSelectingArea else { return }
        waypointViewModel.startPlacing(at: coordinate)
        sheets.editingWaypoint = nil
        sheets.showWaypointEdit = true
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
                routes: routeViewModel.visibleRoutes,
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
                }
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
                weatherWidget: showWeatherWidget ? AnyView(
                    WeatherWidgetView(viewModel: weatherViewModel) {
                        sheets.showWeatherSheet = true
                    }
                ) : nil,
                showCompass: showCompass,
                showZoomControls: showZoomControls,
                showScaleBar: showScaleBar,
                hideMenuAndZoom: routeViewModel.isDrawing || measurementViewModel.isActive || offlineViewModel.isSelectingArea,
                isConnected: connectivityMonitor.isConnected
            )

            if routeViewModel.isDrawing {
                drawingToolbar
            }

            if measurementViewModel.isActive {
                measurementToolbar
            }

            if offlineViewModel.isSelectingArea {
                selectionToolbar
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
                POIDetailSheet(poi: poi)
                    .presentationDetents([.medium])
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
                RouteDetailSheet(viewModel: routeViewModel, route: route)
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
                    }
                )
                .presentationDetents([.medium])
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
    }

    // MARK: - Drawing Toolbar

    private var drawingToolbar: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                if routeViewModel.drawingCoordinates.count >= 2 {
                    HStack(spacing: 6) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.caption)
                        Text(routeViewModel.formattedDrawingDistance)
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(Color.Trakke.brand)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                } else {
                    Text(String(localized: "route.drawingHint"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }

                HStack(spacing: 16) {
                    Button(role: .destructive) {
                        routeViewModel.cancelDrawing()
                    } label: {
                        Label(String(localized: "common.cancel"), systemImage: "xmark")
                            .foregroundStyle(Color.Trakke.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }

                    Button {
                        routeViewModel.undoLastPoint()
                    } label: {
                        Label(String(localized: "route.undo"), systemImage: "arrow.uturn.backward")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .disabled(routeViewModel.drawingCoordinates.isEmpty)

                    Button {
                        sheets.showRouteSave = true
                    } label: {
                        Label(String(localized: "common.done"), systemImage: "checkmark")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.Trakke.brand)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(routeViewModel.drawingCoordinates.count < 2)
                }
            }
            .padding(.bottom, 16)
        }
        .safeAreaPadding(.bottom)
    }

    // MARK: - Measurement Toolbar

    private var measurementToolbar: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                if let result = measurementViewModel.formattedResult {
                    VStack(spacing: 2) {
                        Text(measurementViewModel.mode == .distance
                             ? String(localized: "measurement.distance")
                             : String(localized: "measurement.area"))
                            .font(.caption)
                            .foregroundStyle(Color.Trakke.textSoft)
                        Text(result)
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(Color.Trakke.brand)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                } else {
                    Text(measurementViewModel.mode == .distance
                         ? String(localized: "measurement.distanceHint")
                         : String(localized: "measurement.areaHint"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }

                HStack(spacing: 16) {
                    Button(role: .destructive) {
                        measurementViewModel.stop()
                    } label: {
                        Label(String(localized: "common.cancel"), systemImage: "xmark")
                            .foregroundStyle(Color.Trakke.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }

                    Button {
                        measurementViewModel.undoLastPoint()
                    } label: {
                        Label(String(localized: "route.undo"), systemImage: "arrow.uturn.backward")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .disabled(measurementViewModel.points.isEmpty)

                    Button {
                        measurementViewModel.clearAll()
                    } label: {
                        Label(String(localized: "measurement.clear"), systemImage: "trash")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .disabled(measurementViewModel.points.isEmpty)
                }
            }
            .padding(.bottom, 16)
        }
        .safeAreaPadding(.bottom)
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                if offlineViewModel.hasValidSelection {
                    let count = offlineViewModel.estimatedTileCount
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.3x3")
                            .font(.caption)
                        Text(String(localized: "offline.tiles \(count)"))
                            .font(.subheadline.monospacedDigit())
                        Text("(\(offlineViewModel.estimatedSize))")
                            .font(.caption)
                            .foregroundStyle(Color.Trakke.textSoft)
                    }
                    .foregroundStyle(count > 20_000 ? Color.Trakke.red : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                }

                HStack(spacing: 16) {
                    Button(role: .destructive) {
                        offlineViewModel.cancelSelection()
                    } label: {
                        Label(String(localized: "common.cancel"), systemImage: "xmark")
                            .foregroundStyle(Color.Trakke.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }

                    Button {
                        sheets.showDownloadArea = true
                    } label: {
                        Label(String(localized: "common.done"), systemImage: "checkmark")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.Trakke.brand)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(!offlineViewModel.hasValidSelection)
                }
            }
            .padding(.bottom, 16)
        }
        .safeAreaPadding(.bottom)
    }

}

#Preview {
    ContentView()
}
