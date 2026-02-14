import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var mapViewModel = MapViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var poiViewModel = POIViewModel()
    @State private var routeViewModel = RouteViewModel()
    @State private var showSearchSheet = false
    @State private var showCategoryPicker = false
    @State private var showPOIDetail = false
    @State private var showRouteList = false
    @State private var showRouteDetail = false
    @State private var showRouteName = false
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
        }
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
                onViewportChanged: { bounds, zoom in
                    poiViewModel.viewportChanged(bounds: bounds, zoom: zoom)
                },
                onPOISelected: { poi in
                    poiViewModel.selectPOI(poi)
                    showPOIDetail = true
                },
                onMapTapped: { coordinate in
                    routeViewModel.addPoint(coordinate)
                }
            )
            .ignoresSafeArea()

            MapControlsOverlay(
                viewModel: mapViewModel,
                onSearchTapped: { showSearchSheet = true },
                onCategoryTapped: { showCategoryPicker = true },
                onRouteTapped: { showRouteList = true }
            )
            .padding(.top)

            if routeViewModel.isDrawing {
                drawingToolbar
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
                    onViewportChanged: { bounds, zoom in
                        poiViewModel.viewportChanged(bounds: bounds, zoom: zoom)
                    },
                    onPOISelected: { poi in
                        poiViewModel.selectPOI(poi)
                        showPOIDetail = true
                    },
                    onMapTapped: { coordinate in
                        routeViewModel.addPoint(coordinate)
                    }
                )
                .ignoresSafeArea()

                MapControlsOverlay(viewModel: mapViewModel)
                    .padding(.top)

                if routeViewModel.isDrawing {
                    drawingToolbar
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
