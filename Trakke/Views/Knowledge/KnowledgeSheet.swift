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
                    .navigationDestination(for: KnowledgeDestination.self) { destination in
                        switch destination {
                        case .category(let category):
                            KnowledgeCategoryView(category: category, viewModel: viewModel)
                        case .article(let article):
                            ArticleDetailView(article: article)
                        case .mapLegend:
                            MapLegendView()
                        }
                    }
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
            return .article(article)
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
    case article(KnowledgeArticle)
    case mapLegend
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
                                NavigationLink(value: KnowledgeDestination.article(article)) {
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
