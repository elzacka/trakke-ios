import SwiftUI

/// Info-fanen — Vær, Kunnskap, Om i tre underfaner.
/// Bruker inline-modus av WeatherSheet, KnowledgeSheet og InfoSheet for å
/// gjenbruke alt eksisterende innhold uten dobbel header eller dobbel
/// NavigationStack. Egen NavigationStack rundt håndterer push-navigasjon
/// (vær-dag-detalj og kunnskapsartikler).
struct InfoTabContent: View {
    @Bindable var weatherViewModel: WeatherViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    let connectivityMonitor: ConnectivityMonitor
    @State private var selectedSubTab: Int = 0

    private let subTabs = [
        String(localized: "weather.title"),
        String(localized: "knowledge.title"),
        String(localized: "about.title"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrakkeSheetHeader(title: String(localized: "appTab.info"))

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
            .navigationDestination(for: KnowledgeDestination.self) { destination in
                switch destination {
                case .category(let category):
                    KnowledgeCategoryView(category: category, viewModel: knowledgeViewModel)
                case .article(let article):
                    ArticleDetailView(article: article)
                }
            }
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
