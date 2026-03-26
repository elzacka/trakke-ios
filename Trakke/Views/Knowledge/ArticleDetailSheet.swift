import SwiftUI

// MARK: - Article Detail View (reusable, no NavigationStack)

struct ArticleDetailView: View {
    let article: KnowledgeArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                // MARK: - Body
                MarkdownBodyView(markdown: article.body)

                // MARK: - Source
                if !article.source.isEmpty {
                    CardSection(String(localized: "knowledge.source")) {
                        VStack(alignment: .leading, spacing: .Trakke.xs) {
                            Text(article.source)
                                .font(Font.Trakke.bodyRegular)

                            if let urlString = article.sourceURL,
                               let url = URL(string: urlString),
                               url.scheme == "https" {
                                Link(destination: url) {
                                    HStack {
                                        Text(String(localized: "poi.moreInfo"))
                                            .font(Font.Trakke.bodyRegular)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(Font.Trakke.captionSoft)
                                            .foregroundStyle(Color.Trakke.textTertiary)
                                    }
                                }
                            }
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
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let category = article.articleCategory {
                    Image(systemName: category.iconName)
                        .foregroundStyle(Color.Trakke.brand)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

// MARK: - Article Detail Sheet (standalone presentation)

struct ArticleDetailSheet: View {
    let article: KnowledgeArticle

    var body: some View {
        NavigationStack {
            ArticleDetailView(article: article)
        }
    }
}
