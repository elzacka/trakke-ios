import SwiftUI

struct ContentView: View {
    @State private var mapViewModel = MapViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var showSearchSheet = false
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
            TrakkeMapView(viewModel: mapViewModel)
                .ignoresSafeArea()

            MapControlsOverlay(viewModel: mapViewModel) {
                showSearchSheet = true
            }
            .padding(.top)
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheet(viewModel: searchViewModel) { result in
                mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                Section(String(localized: "search.title")) {
                    searchField
                    searchResults
                }

                Section(String(localized: "settings.baseLayer")) {
                    MapLayerPicker(selectedLayer: $mapViewModel.baseLayer)
                }
            }
            .navigationTitle("Trakke")
        } detail: {
            ZStack {
                TrakkeMapView(viewModel: mapViewModel)
                    .ignoresSafeArea()

                MapControlsOverlay(viewModel: mapViewModel)
                    .padding(.top)
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
