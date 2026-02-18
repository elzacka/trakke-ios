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
    @AppStorage("showWeatherWidget") private var showWeatherWidget = false
    @AppStorage("showCompass") private var showCompass = true
    @AppStorage("showZoomControls") private var showZoomControls = false
    @AppStorage("showScaleBar") private var showScaleBar = false
    @AppStorage("enableRotation") private var enableRotation = true
    @AppStorage("overlayTurrutebasen") private var overlayTurrutebasen = false
    @AppStorage("overlayNaturskog") private var overlayNaturskog = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            routeViewModel.setModelContext(modelContext)
            routeViewModel.loadRoutes()
            waypointViewModel.setModelContext(modelContext)
            waypointViewModel.loadWaypoints()
            offlineViewModel.startObserving()
            syncOverlays()
        }
        .onChange(of: overlayTurrutebasen) { syncOverlays() }
        .onChange(of: overlayNaturskog) { syncOverlays() }
        .onDisappear {
            offlineViewModel.stopObserving()
        }
        .onChange(of: searchViewModel.query) {
            mapViewModel.searchPinCoordinate = nil
        }
    }

    // MARK: - Overlay Sync

    private func syncOverlays() {
        var overlays = Set<OverlayLayer>()
        if overlayTurrutebasen { overlays.insert(.turrutebasen) }
        if overlayNaturskog { overlays.insert(.naturskog) }
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

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
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
                    if routeViewModel.routes.isEmpty {
                        routeViewModel.startDrawing()
                    } else {
                        sheets.showRouteList = true
                    }
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
                hideMenuAndZoom: routeViewModel.isDrawing || measurementViewModel.isActive || offlineViewModel.isSelectingArea
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

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                Section(String(localized: "search.title")) {
                    searchField
                    searchResults
                }

                Section(String(localized: "routes.title")) {
                    ForEach(routeViewModel.routes, id: \.id) { route in
                        Button {
                            routeViewModel.selectRoute(route)
                            sheets.showRouteDetail = true
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: route.color ?? "#3e4533"))
                                    .frame(width: 10, height: 10)
                                Text(route.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    Button {
                        routeViewModel.startDrawing()
                    } label: {
                        Label(String(localized: "routes.new"), systemImage: "plus")
                    }
                }

                Section(String(localized: "waypoints.title")) {
                    ForEach(waypointViewModel.waypoints, id: \.id) { waypoint in
                        Button {
                            waypointViewModel.selectedWaypoint = waypoint
                            sheets.showWaypointDetail = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin")
                                    .font(.caption)
                                    .foregroundStyle(Color.Trakke.brand)
                                Text(waypoint.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                Section(String(localized: "offline.title")) {
                    ForEach(offlineViewModel.packs) { pack in
                        HStack {
                            Text(pack.name)
                            Spacer()
                            if pack.progress.isComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.Trakke.brand)
                                    .font(.caption)
                            } else {
                                ProgressView(value: pack.progress.percentage, total: 100)
                                    .frame(width: 60)
                            }
                        }
                    }

                    Button {
                        offlineViewModel.startSelection(
                            center: mapViewModel.currentCenter,
                            zoom: mapViewModel.currentZoom
                        )
                    } label: {
                        Label(String(localized: "offline.download"), systemImage: "plus")
                    }
                }

                Section(String(localized: "weather.title")) {
                    if let forecast = weatherViewModel.forecast {
                        Button { sheets.showWeatherSheet = true } label: {
                            HStack(spacing: 8) {
                                Image(forecast.current.symbol)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                Text("\(Int(forecast.current.temperature.rounded()))°")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(String(format: "%.1f m/s", forecast.current.windSpeed))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if weatherViewModel.isLoading {
                        ProgressView()
                    }
                }

                Section(String(localized: "categories.title")) {
                    ForEach(POICategory.allCases.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }) { category in
                        Button {
                            poiViewModel.toggleCategory(category)
                        } label: {
                            HStack(spacing: 12) {
                                Image(category.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color(hex: category.color))
                                    .frame(width: 28)
                                Text(category.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if poiViewModel.enabledCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.Trakke.brand)
                                }
                            }
                        }
                    }
                }

                Section(String(localized: "settings.baseLayer")) {
                    MapLayerPicker(selectedLayer: $mapViewModel.baseLayer)
                }

                Section {
                    Button { sheets.showPreferences = true } label: {
                        Label(String(localized: "settings.title"), systemImage: "gearshape")
                    }
                    Button { sheets.showInfo = true } label: {
                        Label(String(localized: "info.title"), systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Tråkke")
            .tint(Color.Trakke.brand)
        } detail: {
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
                    onMeasurementTapped: { sheets.showMeasurementSheet = true },
                    enabledOverlays: mapViewModel.enabledOverlays,
                    weatherWidget: showWeatherWidget ? AnyView(
                        WeatherWidgetView(viewModel: weatherViewModel) {
                            sheets.showWeatherSheet = true
                        }
                    ) : nil,
                    showCompass: showCompass,
                    showZoomControls: showZoomControls,
                    showScaleBar: showScaleBar,
                    hideMenuAndZoom: routeViewModel.isDrawing || measurementViewModel.isActive || offlineViewModel.isSelectingArea
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
            }
            .sheet(isPresented: $sheets.showPOIDetail) {
                if let poi = poiViewModel.selectedPOI {
                    POIDetailSheet(poi: poi)
                        .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $sheets.showRouteDetail) {
                if let route = routeViewModel.selectedRoute {
                    RouteDetailSheet(viewModel: routeViewModel, route: route)
                        .presentationDetents([.medium, .large])
                }
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
                    .presentationDetents([.height(200), .medium])
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(200)))
            }
            .sheet(isPresented: $sheets.showPreferences) {
                PreferencesSheet(mapViewModel: mapViewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $sheets.showInfo) {
                InfoSheet()
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
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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

    // MARK: - iPad Search Components

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(String(localized: "search.placeholder"), text: Binding(
                get: { searchViewModel.query },
                set: { searchViewModel.updateQuery($0) }
            ))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !searchViewModel.query.isEmpty {
                Button {
                    searchViewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var searchResults: some View {
        ForEach(searchViewModel.results) { result in
            SearchResultRow(result: result)
                .onTapGesture {
                    searchViewModel.selectResult(result)
                    mapViewModel.searchPinCoordinate = result.coordinate
                    mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
                }
        }
    }
}

#Preview {
    ContentView()
}
