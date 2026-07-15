import SwiftUI

// MARK: - Tooltip Content View

/// Tooltip content view styled like the rest of the app – CardSection på
/// cream-bakgrunn, samme typografi (bodyMedium / bodyRegular) som InfoSheet
/// og list-arkene. Sitter inni en TooltipSheet som gir presentation-detents,
/// navigation-stack for artikkel-linker, og felles ark-styling.
struct TrakkeTooltipContent: View {
    let title: String
    let text: String
    var sections: [(header: String, text: String)] = []
    var source: String? = nil

    var body: some View {
        CardSection {
            VStack(alignment: .leading, spacing: .Trakke.sm) {
                if !title.isEmpty {
                    Text(title)
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.text)
                }

                if !text.isEmpty {
                    Text(text)
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    if !section.header.isEmpty {
                        Text(section.header)
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.text)
                            .padding(.top, .Trakke.sm)
                    }
                    Text(section.text)
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let source {
                    Divider().padding(.vertical, .Trakke.xs)
                    Text(source)
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
            }
            .padding(.vertical, .Trakke.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

/// Internal sheet view that provides NavigationStack for article linking and
/// felles ark-bakgrunn/-padding på linje med InfoSheet og list-arkene.
private struct TooltipSheet<TooltipContent: View>: View {
    @ViewBuilder let tooltipContent: () -> TooltipContent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                    tooltipContent()
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
                .padding(.bottom, .Trakke.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.Trakke.background)
            .tint(Color.Trakke.brand)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: KnowledgeArticle.self) { article in
                ArticleDetailView(article: article)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.Trakke.background)
        .presentationCornerRadius(.TrakkeRadius.sheet)
    }
}

// MARK: - Article Link View

/// Tappable link shown below a tooltip to navigate to a Knowledge article.
/// Eget kort med TrakkeMenuRow – samme stil som menyrader ellers i appen.
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
            CardSection {
                NavigationLink(value: article) {
                    TrakkeMenuRow(
                        icon: "book",
                        label: String(localized: "tooltip.readMore \(article.title.lowercased())"),
                        trailing: { TrakkeMenuRowChevron() }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Source Link View

/// Tappable external link below a tooltip – eget kort, samme stil som
/// menyrader. Use for linking to external sources like varsom.no.
struct TooltipSourceLink: View {
    let label: String
    let url: URL

    var body: some View {
        CardSection {
            Link(destination: url) {
                TrakkeMenuRow(
                    label: label,
                    trailing: { TrakkeMenuRowExternal() }
                )
            }
            .accessibilityHint(String(localized: "accessibility.opensExternalLink"))
        }
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
