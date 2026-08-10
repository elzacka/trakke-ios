import SwiftUI

// MARK: - Article Detail View (reusable, no NavigationStack)

struct ArticleDetailView: View {
    let article: KnowledgeArticle
    /// Overskriften artikkelen åpner på. Settes når visningen nås fra en verdi
    /// et annet sted i appen – en værrad peker på avsnittet som forklarer
    /// akkurat den verdien. nil åpner artikkelen fra toppen.
    var section: String? = nil

    var body: some View {
        TrakkePushedPage(title: article.title) {
            ScrollView {
                ScrollViewReader { proxy in
                    articleBody(proxy)
                        .padding(.horizontal, .Trakke.sheetHorizontal)
                        .padding(.top, .Trakke.sheetTop)
                }
            }
        }
    }

    private func articleBody(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.cardGap) {
            MarkdownBodyView(markdown: article.body, onParsed: {
                guard let section else { return }
                proxy.scrollTo(MarkdownHeadingAnchor(heading: section), anchor: .top)
            })

            if !article.source.isEmpty {
                sourceCard
            }

            Spacer(minLength: .Trakke.lg)
        }
    }

    @ViewBuilder
    private var sourceCard: some View {
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
}
