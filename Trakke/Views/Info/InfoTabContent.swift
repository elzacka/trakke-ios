import CoreLocation
import SwiftUI

/// Info-fanen – Vær, Kunnskap, Om i tre underfaner.
/// Bruker inline-modus av WeatherSheet, KnowledgeSheet og InfoSheet for å
/// gjenbruke alt eksisterende innhold uten dobbel header eller dobbel
/// NavigationStack. Egen NavigationStack rundt håndterer push-navigasjon
/// (vær-dag-detalj og kunnskapsartikler).
struct InfoTabContent: View {
    @Bindable var weatherViewModel: WeatherViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    let connectivityMonitor: ConnectivityMonitor
    /// Ren referanse – ingen @Bindable. Koordinaten leses kun inne i
    /// onAppear/onChange-handlere, som ikke registrerer Observation-avhengigheter,
    /// så GPS-oppdateringer (~1 Hz) re-rendrer ikke Info-fanen.
    let mapViewModel: MapViewModel
    @State private var selectedSubTab: Int = 0

    private var mapCenter: CLLocationCoordinate2D {
        mapViewModel.userLocation?.coordinate ?? mapViewModel.currentCenter
    }

    private let subTabs = [
        String(localized: "weather.title"),
        String(localized: "knowledge.title"),
        String(localized: "about.title"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrakkeSheetHeader()

                TrakkeUnderlineTabs(
                    titles: subTabs,
                    selectedIndex: $selectedSubTab
                )

                ScrollView {
                    tabContent(for: selectedSubTab)
                        .padding(.horizontal, .Trakke.sheetHorizontal)
                        .padding(.top, .Trakke.lg)
                        .padding(.bottom, .Trakke.xxl + 60)
                }
            }
            .background(Color.Trakke.background)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                weatherViewModel.fetchForecast(for: mapCenter)
            }
            .onChange(of: selectedSubTab) { _, new in
                if new == 0 { weatherViewModel.fetchForecast(for: mapCenter) }
            }
            .knowledgeDestinations(viewModel: knowledgeViewModel)
        }
    }

    @ViewBuilder
    private func tabContent(for index: Int) -> some View {
        switch index {
        case 0:
            WeatherSheet(viewModel: weatherViewModel, inline: true)
        case 1:
            KnowledgeSheet(viewModel: knowledgeViewModel, inline: true)
        case 2:
            InfoSheet(inline: true, connectivityMonitor: connectivityMonitor)
        default:
            EmptyView()
        }
    }
}
