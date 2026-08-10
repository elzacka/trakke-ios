import SwiftUI

struct KnowledgeSheet: View {
    @Bindable var viewModel: KnowledgeViewModel
    var isEmbedded = false
    /// Inline-modus: ingen ScrollView/NavigationStack/title – kalleren
    /// (f.eks. accordion-vert) håndterer scroll og kontekst.
    var inline = false

    var body: some View {
        if inline {
            contentVStack
        } else if isEmbedded {
            knowledgeContent
        } else {
            NavigationStack {
                knowledgeContent
                    .knowledgeDestinations(viewModel: viewModel)
            }
        }
    }

    private var sortedCategories: [ArticleCategory] {
        ArticleCategory.allCases.sorted {
            $0.displayName.localizedCompare($1.displayName) == .orderedAscending
        }
    }

    private func articlesForCategory(_ category: ArticleCategory) -> [KnowledgeArticle] {
        viewModel.articles.filter { $0.category == category.rawValue }
    }

    private func destination(for category: ArticleCategory) -> KnowledgeDestination {
        let articles = articlesForCategory(category)
        if articles.count == 1, let article = articles.first {
            return .article(article, section: nil)
        }
        return .category(category)
    }

    private var knowledgeContent: some View {
        ScrollView {
            contentVStack
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "knowledge.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var contentVStack: some View {
        VStack(spacing: .Trakke.cardGap) {
            CardSection(String(localized: "knowledge.categories")) {
                ForEach(Array(sortedCategories.enumerated()), id: \.element) { index, category in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    NavigationLink(value: destination(for: category)) {
                        TrakkeMenuRow(
                            label: category.displayName,
                            trailing: { TrakkeMenuRowChevron() }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: .Trakke.lg)
        }
        .padding(.horizontal, inline ? 0 : .Trakke.sheetHorizontal)
        .padding(.top, inline ? 0 : .Trakke.sheetTop)
        .task {
            await viewModel.loadArticles()
            viewModel.fetchRemoteArticleUpdates()
        }
    }
}

// MARK: - Knowledge Destination

enum KnowledgeDestination: Hashable {
    case category(ArticleCategory)
    /// `section` er overskriften det scrolles til i artikkelen. Brukes når
    /// en verdi et annet sted i appen – f.eks. en værrad – peker på det
    /// avsnittet som forklarer akkurat den verdien. nil åpner fra toppen.
    case article(KnowledgeArticle, section: String? = nil)
    case mapLegend
}

extension View {
    /// Registrerer Kunnskap-destinasjonene på en NavigationStack. Alle verter
    /// som kan lenke til en artikkel – Kunnskap, Info-fanen og Vær – bruker
    /// denne, slik at en ny destinasjon ikke må legges inn tre steder og bli
    /// glemt på ett av dem.
    ///
    /// `viewModel` er nil for verter som bare lenker til enkeltartikler, ikke
    /// til kategorilister (Vær).
    func knowledgeDestinations(viewModel: KnowledgeViewModel?) -> some View {
        navigationDestination(for: KnowledgeDestination.self) { destination in
            switch destination {
            case .category(let category):
                if let viewModel {
                    KnowledgeCategoryView(category: category, viewModel: viewModel)
                }
            case .article(let article, let section):
                ArticleDetailView(article: article, section: section)
            case .mapLegend:
                MapLegendView()
            }
        }
    }
}

// MARK: - Bundled Article Lookup

/// Oppslag av bundlede artikler på id. Værradene peker rett inn i Kunnskap,
/// og forklaringen må finnes uten dekning og uten at et ark først venter på
/// at artikler lastes – derfor de bundlede, ikke `KnowledgeViewModel.articles`.
@MainActor
enum BundledArticles {
    static func article(_ id: Int64) -> KnowledgeArticle? { byID[id] }

    private static let byID: [Int64: KnowledgeArticle] = Dictionary(
        KnowledgeViewModel.loadBundledArticles().map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )
}

// MARK: - Article Category View

struct KnowledgeCategoryView: View {
    let category: ArticleCategory
    @Bindable var viewModel: KnowledgeViewModel

    // Alfabetisk på tittel, med norsk sortering (æ, ø, å sist) – samme
    // regel som kategorilista. Unntak: Beredskap leses i den rekkefølgen
    // temaene blir aktuelle i en krise (forberedelse → varsling →
    // informasjon → oppholdssted → tilfluktsrom), styrt av sortOrder i
    // SurvivalArticles.json.
    private var filteredArticles: [KnowledgeArticle] {
        let inCategory = viewModel.articles.filter { $0.category == category.rawValue }
        if category == .beredskap {
            return inCategory.sorted { $0.sortOrder < $1.sortOrder }
        }
        return inCategory.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        TrakkePushedPage(title: category.displayName) {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    if filteredArticles.isEmpty {
                        EmptyStateView(
                            title: String(localized: "knowledge.articles.empty"),
                            subtitle: String(localized: "knowledge.articles.empty.subtitle")
                        )
                    } else {
                        CardSection(String(localized: "knowledge.articles")) {
                            ForEach(Array(filteredArticles.enumerated()), id: \.element.id) { index, article in
                                if index > 0 {
                                    Divider().padding(.leading, .Trakke.dividerLeading)
                                }
                                NavigationLink(value: KnowledgeDestination.article(article, section: nil)) {
                                    TrakkeMenuRow(
                                        label: article.title,
                                        trailing: { TrakkeMenuRowChevron() }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
        }
    }
}
