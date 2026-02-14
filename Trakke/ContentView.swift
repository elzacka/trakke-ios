import SwiftUI

struct ContentView: View {
    @State private var mapViewModel = MapViewModel()
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

            MapControlsOverlay(viewModel: mapViewModel)
                .padding(.top)
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
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
}

#Preview {
    ContentView()
}
