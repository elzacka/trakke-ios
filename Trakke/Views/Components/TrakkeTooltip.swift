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
        // Tittelen går til `CardSection`, som gir den appens
        // seksjonsoverskrift over kortet – samme form som «AKKURAT NÅ» og
        // «NETTVERKSSTATUS». Før lå den inni kortet med samme vekt som
        // avsnittsoverskriftene under, så ingenting skilte nivåene.
        CardSection(title) {
            VStack(alignment: .leading, spacing: .Trakke.sm) {
                if !text.isEmpty {
                    formatted(text)
                }

                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    if !section.header.isEmpty {
                        Text(section.header)
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.text)
                            .padding(.top, .Trakke.sm)
                    }
                    formatted(section.text)
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

    /// Kulepunkt får kula i egen kolonne. Rendret som én `Text` la ombrukket
    /// linje starte under kula i stedet for under teksten, og en liste med
    /// fem nivåer ble en vegg. Tomme linjer blir avsnittsluft.
    @ViewBuilder
    private func formatted(_ raw: String) -> some View {
        let lines = raw.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: .Trakke.xs) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.isEmpty {
                    Color.clear.frame(height: .Trakke.xs)
                } else if line.hasPrefix("\u{2022} ") {
                    HStack(alignment: .firstTextBaseline, spacing: .Trakke.sm) {
                        Text("\u{2022}")
                        Text(String(line.dropFirst(2)))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textSecondary)
                } else {
                    Text(line)
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
            VStack(spacing: 0) {
                // Appens egen grabber, som i alle andre ark. Uten den fikk
                // vær-forklaringene systemets indikator og skilte seg ut.
                TrakkeSheetHeader()

                ScrollView {
                    VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                        tooltipContent()
                    }
                    .padding(.horizontal, .Trakke.sheetHorizontal)
                    .padding(.bottom, .Trakke.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        .presentationDragIndicator(.hidden)
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
