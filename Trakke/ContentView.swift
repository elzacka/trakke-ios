import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @State private var mapViewModel = MapViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var poiViewModel = POIViewModel()
    @State private var routeViewModel = RouteViewModel()
    @State private var offlineViewModel = OfflineViewModel()
    @State private var weatherViewModel = WeatherViewModel()
    @State private var measurementViewModel = MeasurementViewModel()
    @State private var showSearchSheet = false
    @State private var showCategoryPicker = false
    @State private var showPOIDetail = false
    @State private var showRouteList = false
    @State private var showRouteDetail = false
    @State private var showRouteName = false
    @State private var showOfflineManager = false
    @State private var showDownloadArea = false
    @State private var showWeatherSheet = false
    @State private var showMeasurementSheet = false
    @State private var showPreferences = false
    @State private var showInfo = false
    @State private var newRouteName = ""
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
            let container = modelContext.container
            routeViewModel.setModelContainer(container)
            routeViewModel.loadRoutes()
            offlineViewModel.startObserving()
        }
        .onDisappear {
            offlineViewModel.stopObserving()
        }
    }

    // MARK: - Map Tap Handler

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        if offlineViewModel.isSelectingArea {
            offlineViewModel.addSelectionPoint(coordinate)
            if offlineViewModel.hasValidSelection {
                showDownloadArea = true
            }
        } else if measurementViewModel.isActive {
            measurementViewModel.addPoint(coordinate)
        } else if routeViewModel.isDrawing {
            routeViewModel.addPoint(coordinate)
        }
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
                routes: routeViewModel.routes,
                drawingCoordinates: routeViewModel.drawingCoordinates,
                isDrawing: routeViewModel.isDrawing,
                selectionCorner1: offlineViewModel.selectionCorner1,
                selectionCorner2: offlineViewModel.selectionCorner2,
                measurementCoordinates: measurementViewModel.points,
                measurementMode: measurementViewModel.mode,
                onViewportChanged: handleViewportChanged,
                onPOISelected: { poi in
                    poiViewModel.selectPOI(poi)
                    showPOIDetail = true
                },
                onMapTapped: handleMapTap
            )
            .ignoresSafeArea()

            MapControlsOverlay(
                viewModel: mapViewModel,
                onSearchTapped: { showSearchSheet = true },
                onCategoryTapped: { showCategoryPicker = true },
                onRouteTapped: { showRouteList = true },
                onOfflineTapped: { showOfflineManager = true },
                onWeatherTapped: { showWeatherSheet = true },
                onMeasurementTapped: { showMeasurementSheet = true },
                onSettingsTapped: { showPreferences = true },
                onInfoTapped: { showInfo = true },
                weatherWidget: AnyView(
                    WeatherWidgetView(viewModel: weatherViewModel) {
                        showWeatherSheet = true
                    }
                )
            )
            .padding(.top)

            if routeViewModel.isDrawing {
                drawingToolbar
            }

            if measurementViewModel.isActive {
                measurementToolbar
            }

            if offlineViewModel.isSelectingArea && !offlineViewModel.hasValidSelection {
                selectionHint
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheet(viewModel: searchViewModel) { result in
                mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(viewModel: poiViewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPOIDetail) {
            if let poi = poiViewModel.selectedPOI {
                POIDetailSheet(poi: poi)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showRouteList) {
            RouteListSheet(
                viewModel: routeViewModel,
                onRouteSelected: { route in
                    routeViewModel.selectRoute(route)
                    showRouteDetail = true
                },
                onNewRoute: {
                    routeViewModel.startDrawing()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRouteDetail) {
            if let route = routeViewModel.selectedRoute {
                RouteDetailSheet(viewModel: routeViewModel, route: route)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showOfflineManager) {
            DownloadManagerSheet(
                viewModel: offlineViewModel,
                onNewDownload: {
                    offlineViewModel.startSelection()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDownloadArea) {
            DownloadAreaSheet(viewModel: offlineViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherSheet(viewModel: weatherViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMeasurementSheet) {
            MeasurementSheet(viewModel: measurementViewModel)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(measurementViewModel.isActive)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesSheet(mapViewModel: mapViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showInfo) {
            InfoSheet()
                .presentationDetents([.medium, .large])
        }
        .alert(String(localized: "routes.namePrompt"), isPresented: $showRouteName) {
            TextField(String(localized: "routes.namePlaceholder"), text: $newRouteName)
            Button(String(localized: "common.save")) {
                routeViewModel.finishDrawing(name: newRouteName)
                newRouteName = ""
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                newRouteName = ""
            }
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
                            showRouteDetail = true
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

                Section(String(localized: "offline.title")) {
                    ForEach(offlineViewModel.packs) { pack in
                        HStack {
                            Text(pack.name)
                            Spacer()
                            if pack.progress.isComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            } else {
                                ProgressView(value: pack.progress.percentage, total: 100)
                                    .frame(width: 60)
                            }
                        }
                    }

                    Button {
                        offlineViewModel.startSelection()
                    } label: {
                        Label(String(localized: "offline.download"), systemImage: "plus")
                    }
                }

                Section(String(localized: "weather.title")) {
                    if let forecast = weatherViewModel.forecast {
                        Button { showWeatherSheet = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: WeatherViewModel.sfSymbol(for: forecast.current.symbol))
                                    .foregroundStyle(.orange)
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
                    ForEach(POICategory.allCases) { category in
                        Button {
                            poiViewModel.toggleCategory(category)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.iconName)
                                    .foregroundStyle(Color(hex: category.color))
                                    .frame(width: 28)
                                Text(category.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if poiViewModel.enabledCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section(String(localized: "settings.baseLayer")) {
                    MapLayerPicker(selectedLayer: $mapViewModel.baseLayer)
                }

                Section {
                    Button { showPreferences = true } label: {
                        Label(String(localized: "settings.title"), systemImage: "gearshape")
                    }
                    Button { showInfo = true } label: {
                        Label(String(localized: "info.title"), systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Trakke")
        } detail: {
            ZStack {
                TrakkeMapView(
                    viewModel: mapViewModel,
                    pois: poiViewModel.pois,
                    routes: routeViewModel.routes,
                    drawingCoordinates: routeViewModel.drawingCoordinates,
                    isDrawing: routeViewModel.isDrawing,
                    selectionCorner1: offlineViewModel.selectionCorner1,
                    selectionCorner2: offlineViewModel.selectionCorner2,
                    measurementCoordinates: measurementViewModel.points,
                    measurementMode: measurementViewModel.mode,
                    onViewportChanged: handleViewportChanged,
                    onPOISelected: { poi in
                        poiViewModel.selectPOI(poi)
                        showPOIDetail = true
                    },
                    onMapTapped: handleMapTap
                )
                .ignoresSafeArea()

                MapControlsOverlay(
                    viewModel: mapViewModel,
                    onMeasurementTapped: { showMeasurementSheet = true },
                    weatherWidget: AnyView(
                        WeatherWidgetView(viewModel: weatherViewModel) {
                            showWeatherSheet = true
                        }
                    )
                )
                .padding(.top)

                if routeViewModel.isDrawing {
                    drawingToolbar
                }

                if measurementViewModel.isActive {
                    measurementToolbar
                }

                if offlineViewModel.isSelectingArea && !offlineViewModel.hasValidSelection {
                    selectionHint
                }
            }
            .sheet(isPresented: $showPOIDetail) {
                if let poi = poiViewModel.selectedPOI {
                    POIDetailSheet(poi: poi)
                        .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showRouteDetail) {
                if let route = routeViewModel.selectedRoute {
                    RouteDetailSheet(viewModel: routeViewModel, route: route)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showDownloadArea) {
                DownloadAreaSheet(viewModel: offlineViewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showWeatherSheet) {
                WeatherSheet(viewModel: weatherViewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showMeasurementSheet) {
                MeasurementSheet(viewModel: measurementViewModel)
                    .presentationDetents([.medium])
                    .interactiveDismissDisabled(measurementViewModel.isActive)
            }
            .sheet(isPresented: $showPreferences) {
                PreferencesSheet(mapViewModel: mapViewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showInfo) {
                InfoSheet()
                    .presentationDetents([.medium, .large])
            }
        }
        .alert(String(localized: "routes.namePrompt"), isPresented: $showRouteName) {
            TextField(String(localized: "routes.namePlaceholder"), text: $newRouteName)
            Button(String(localized: "common.save")) {
                routeViewModel.finishDrawing(name: newRouteName)
                newRouteName = ""
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                newRouteName = ""
            }
        }
    }

    // MARK: - Drawing Toolbar

    private var drawingToolbar: some View {
        VStack {
            Spacer()

            HStack(spacing: 16) {
                Button(role: .destructive) {
                    routeViewModel.cancelDrawing()
                } label: {
                    Label(String(localized: "common.cancel"), systemImage: "xmark")
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
                    showRouteName = true
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
            .padding(.bottom, 40)
        }
    }

    // MARK: - Measurement Toolbar

    private var measurementToolbar: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                if let result = measurementViewModel.formattedResult {
                    Text(result)
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(Color.Trakke.brand)
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
            .padding(.bottom, 40)
        }
    }

    // MARK: - Selection Hint

    private var selectionHint: some View {
        VStack {
            HStack {
                Text(offlineViewModel.selectionCorner1 == nil
                     ? String(localized: "offline.tapFirstCorner")
                     : String(localized: "offline.tapSecondCorner"))
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(Capsule())

                Button {
                    offlineViewModel.cancelSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "common.cancel"))
                }
            }
            .padding(.top, 60)

            Spacer()
        }
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
                    mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
                }
        }
    }
}

#Preview {
    ContentView()
}
