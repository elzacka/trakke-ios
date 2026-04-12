import SwiftUI

// MARK: - Tooltip Content View

/// Tooltip content view styled with Trakke design tokens.
struct TrakkeTooltipContent: View {
    let title: String
    let text: String
    var sections: [(header: String, text: String)] = []
    var source: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: .Trakke.sm) {
            if !title.isEmpty {
                Text(title)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)
            }

            if !text.isEmpty {
                Text(text)
                    .font(Font.Trakke.tooltipBody)
                    .foregroundStyle(Color.Trakke.textSecondary)
            }

            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                if !section.header.isEmpty {
                    Text(section.header)
                        .font(Font.Trakke.tooltipBody)
                        .foregroundStyle(Color.Trakke.text)
                        .padding(.top, .Trakke.md)
                }
                Text(section.text)
                    .font(Font.Trakke.tooltipBody)
                    .foregroundStyle(Color.Trakke.textSecondary)
            }

            if let source {
                Divider()
                    .padding(.top, .Trakke.xs)
                Text(source)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
        }
        .padding(.horizontal, .Trakke.lg)
        .padding(.top, .Trakke.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

typealias TrakkeTooltip = TrakkeTooltipContent

// MARK: - Tooltip Modifier

/// Presents a tooltip as a compact bottom sheet with NavigationStack
/// for article linking from TooltipArticleLink.
struct TrakkeTooltipModifier<TooltipContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let tooltipContent: () -> TooltipContent

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                TooltipSheet(tooltipContent: tooltipContent)
            }
    }
}

/// Internal sheet view that provides NavigationStack for article linking.
private struct TooltipSheet<TooltipContent: View>: View {
    @ViewBuilder let tooltipContent: () -> TooltipContent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    tooltipContent()
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: KnowledgeArticle.self) { article in
                ArticleDetailView(article: article)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.Trakke.brandTint)
        .presentationCornerRadius(.TrakkeRadius.sheet)
    }
}

// MARK: - Article Link View

/// Tappable link shown at the bottom of a tooltip to navigate to a Knowledge article.
/// Must be used inside a NavigationStack (provided by TrakkeTooltipModifier).
struct TooltipArticleLink: View {
    let articleId: Int64
    private let article: KnowledgeArticle?

    init(articleId: Int64) {
        self.articleId = articleId
        self.article = Self.cachedArticles[articleId]
    }

    /// Loaded once from the bundle and cached as a static dictionary.
    @MainActor private static let cachedArticles: [Int64: KnowledgeArticle] = {
        let all = KnowledgeViewModel.loadBundledArticles()
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    var body: some View {
        if let article {
            VStack(alignment: .leading, spacing: .Trakke.sm) {
                Divider()
                    .padding(.top, .Trakke.md)

                NavigationLink(value: article) {
                    HStack(spacing: .Trakke.xs) {
                        Image(systemName: "book")
                            .font(Font.Trakke.captionSoft)
                        Text("Les om \(article.title.lowercased()) i Kunnskap")
                            .font(Font.Trakke.tooltipBody)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Font.Trakke.captionSoft)
                    }
                    .foregroundStyle(Color.Trakke.brand)
                }
            }
            .padding(.horizontal, .Trakke.lg)
            .padding(.bottom, .Trakke.lg)
        }
    }
}

// MARK: - Source Link View

/// Tappable external link shown at the bottom of a tooltip.
/// Use for linking to external sources like varsom.no.
struct TooltipSourceLink: View {
    let label: String
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: .Trakke.sm) {
            Divider()
                .padding(.top, .Trakke.xs)
            Link(destination: url) {
                HStack(spacing: .Trakke.xs) {
                    Text(label)
                    Image(systemName: "arrow.up.right")
                        .imageScale(.small)
                }
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.brand)
            }
        }
        .padding(.horizontal, .Trakke.lg)
        .padding(.bottom, .Trakke.lg)
    }
}

extension View {
    func trakkeTooltip<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(TrakkeTooltipModifier(isPresented: isPresented, tooltipContent: content))
    }
}
