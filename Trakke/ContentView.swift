import SwiftUI

struct ContentView: View {
    @State private var mapViewModel = MapViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var poiViewModel = POIViewModel()
    @State private var showSearchSheet = false
    @State private var showCategoryPicker = false
    @State private var showPOIDetail = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    private var iPhoneLayout: some View {
        ZStack {
            TrakkeMapView(
                viewModel: mapViewModel,
                pois: poiViewModel.pois,
                onViewportChanged: { bounds, zoom in
                    poiViewModel.viewportChanged(bounds: bounds, zoom: zoom)
                },
                onPOISelected: { poi in
                    poiViewModel.selectPOI(poi)
                    showPOIDetail = true
                }
            )
            .ignoresSafeArea()

            MapControlsOverlay(
                viewModel: mapViewModel,
                onSearchTapped: { showSearchSheet = true },
                onCategoryTapped: { showCategoryPicker = true }
            )
            .padding(.top)
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
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                Section(String(localized: "search.title")) {
                    searchField
                    searchResults
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
                    onViewportChanged: { bounds, zoom in
                        poiViewModel.viewportChanged(bounds: bounds, zoom: zoom)
                    },
                    onPOISelected: { poi in
                        poiViewModel.selectPOI(poi)
                        showPOIDetail = true
                    }
                )
                .ignoresSafeArea()

                MapControlsOverlay(viewModel: mapViewModel)
                    .padding(.top)
            }
            .sheet(isPresented: $showPOIDetail) {
                if let poi = poiViewModel.selectedPOI {
                    POIDetailSheet(poi: poi)
                        .presentationDetents([.medium])
                }
            }
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
