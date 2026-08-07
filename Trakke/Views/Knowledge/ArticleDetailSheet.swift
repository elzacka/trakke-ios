import SwiftUI

// MARK: - Article Detail View (reusable, no NavigationStack)

struct ArticleDetailView: View {
    let article: KnowledgeArticle

    var body: some View {
        TrakkePushedPage(title: article.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                    MarkdownBodyView(markdown: article.body)

                    if !article.source.isEmpty {
                        CardSection(String(localized: "knowledge.source")) {
                            if let urlString = article.sourceURL,
                               let url = URL(string: urlString),
                               url.scheme == "https" {
                                Link(destination: url) {
                                    HStack {
                                        Text(article.source)
                                            .font(Font.Trakke.bodyRegular)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(Font.Trakke.captionSoft)
                                            .foregroundStyle(Color.Trakke.textSoft)
                                    }
                                }
                            } else {
                                Text(article.source)
                                    .font(Font.Trakke.bodyRegular)
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

// MARK: - Article Detail Sheet (standalone presentation)

struct ArticleDetailSheet: View {
    let article: KnowledgeArticle

    var body: some View {
        NavigationStack {
            ArticleDetailView(article: article)
        }
    }
}
