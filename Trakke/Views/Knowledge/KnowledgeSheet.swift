import SwiftUI

struct KnowledgeSheet: View {
    @Bindable var viewModel: KnowledgeViewModel
    var isEmbedded = false

    var body: some View {
        if isEmbedded {
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
                        }
                    }
            }
        }
    }

    private var knowledgeContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection("") {
                    ForEach(Array(ArticleCategory.allCases.enumerated()), id: \.element) { index, category in
                        if index > 0 {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                        }
                        NavigationLink(value: KnowledgeDestination.category(category)) {
                            HStack(spacing: .Trakke.md) {
                                Image(systemName: category.iconName)
                                    .foregroundStyle(Color.Trakke.brand)
                                    .frame(width: 24)
                                Text(category.displayName)
                                    .font(Font.Trakke.bodyRegular)
                                    .foregroundStyle(Color.Trakke.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(Font.Trakke.captionSoft)
                                    .foregroundStyle(Color.Trakke.textTertiary)
                            }
                            .frame(minHeight: .Trakke.touchMin)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "knowledge.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadArticles()
        }
    }
}

// MARK: - Knowledge Destination

enum KnowledgeDestination: Hashable {
    case category(ArticleCategory)
    case article(KnowledgeArticle)
}

// MARK: - Article Category View

struct KnowledgeCategoryView: View {
    let category: ArticleCategory
    @Bindable var viewModel: KnowledgeViewModel

    private var filteredArticles: [KnowledgeArticle] {
        viewModel.articles.filter { $0.category == category.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                if filteredArticles.isEmpty {
                    EmptyStateView(
                        icon: "book.closed",
                        title: String(localized: "knowledge.articles.empty"),
                        subtitle: String(localized: "knowledge.articles.empty.subtitle")
                    )
                } else {
                    CardSection("") {
                        ForEach(Array(filteredArticles.enumerated()), id: \.element.id) { index, article in
                            if index > 0 {
                                Divider().padding(.leading, .Trakke.dividerLeading)
                            }
                            NavigationLink(value: KnowledgeDestination.article(article)) {
                                HStack {
                                    Text(article.title)
                                        .font(Font.Trakke.bodyRegular)
                                        .foregroundStyle(Color.Trakke.text)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(Font.Trakke.captionSoft)
                                        .foregroundStyle(Color.Trakke.textTertiary)
                                }
                                .frame(minHeight: .Trakke.touchMin)
                                .contentShape(Rectangle())
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
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
