import SwiftUI
import OSLog

/// In-app rendering of the privacy policy. Mirrors the pattern used by
/// UserGuideSheet: fetch the live `PERSONVERN.md` from the GitHub repo so users
/// see updates between app releases, with the bundled copy as offline fallback.
struct PrivacySheet: View {
    /// Inline-modus: ingen egen NavigationStack – kalleren har allerede en
    /// NavigationStack og bruker visningen som push-destinasjon.
    var inline = false
    /// Embedded-modus: rendrer kun markdown-blokkene uten egen ScrollView
    /// og uten navigation-tittel. Brukes når visningen sitter inni en
    /// akkordeon.
    var embedded = false
    @State private var markdown: String?
    @State private var isLoading = true

    private static let remoteURL = URL(
        string: "https://raw.githubusercontent.com/elzacka/trakke-ios/main/PERSONVERN.md"
    )!

    var body: some View {
        Group {
            if embedded {
                embeddedContent
            } else if inline {
                content
            } else {
                NavigationStack {
                    content
                }
            }
        }
        .task {
            await loadPrivacy()
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let markdown, !markdown.isEmpty {
                PrivacyBodyView(markdown: markdown)
            } else {
                ContentUnavailableView(
                    String(localized: "privacy.unavailable"),
                    systemImage: "hand.raised",
                    description: Text(String(localized: "privacy.unavailable.detail"))
                )
            }
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "info.privacy.policy"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var embeddedContent: some View {
        if isLoading {
            HStack {
                ProgressView()
                Spacer()
            }
            .padding(.vertical, .Trakke.sm)
        } else if let markdown, !markdown.isEmpty {
            PrivacyBodyView(markdown: markdown, embedded: true)
        } else {
            Text(String(localized: "privacy.unavailable"))
                .font(Font.Trakke.articleBody)
                .foregroundStyle(Color.Trakke.textSoft)
                .padding(.vertical, .Trakke.sm)
        }
    }

    private func loadPrivacy() async {
        do {
            let data = try await APIClient.fetchData(url: Self.remoteURL, timeout: 10, optional: true)
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                markdown = text
                isLoading = false
                return
            }
        } catch {
            Logger.knowledge.warning("Failed to fetch remote privacy policy: \(error.localizedDescription, privacy: .private)")
        }

        if let bundleURL = Bundle.main.url(forResource: "PERSONVERN", withExtension: "md"),
           let text = try? String(contentsOf: bundleURL, encoding: .utf8) {
            markdown = text
        }
        isLoading = false
    }
}

// MARK: - Privacy Body View

/// Renders the privacy policy as a single continuous scroll. Same parsing
/// pipeline as the user guide, plus table support for the data-sources section.
private struct PrivacyBodyView: View {
    let markdown: String
    /// Embedded: render kun blokkene i en VStack – parent håndterer scroll.
    var embedded: Bool = false
    @State private var parsedBlocks: [MarkdownBlock]?

    private static let parseOptions = MarkdownParserOptions(
        skipH1: true,
        skipTableOfContents: false,
        parseAnchors: false
    )

    var body: some View {
        let blocks = parsedBlocks ?? []

        Group {
            if embedded {
                blocksList(blocks: blocks)
            } else {
                ScrollView {
                    blocksList(blocks: blocks)
                        .padding(.horizontal, .Trakke.sheetHorizontal)
                        .padding(.top, .Trakke.sheetTop)
                }
            }
        }
        .task(id: markdown) {
            parsedBlocks = MarkdownParser.parse(markdown, options: Self.parseOptions)
        }
    }

    @ViewBuilder
    private func blocksList(blocks: [MarkdownBlock]) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.md) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
            Spacer(minLength: embedded ? .Trakke.md : .Trakke.xxl)
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading2(let text, _):
            inlineText(text)
                .font(Font.Trakke.articleHeading)
                .padding(.top, .Trakke.xl)

        case .heading3(let text):
            inlineText(text)
                .font(Font.Trakke.articleSubheading)
                .padding(.top, .Trakke.md)

        case .paragraph(let text):
            inlineText(text)
                .font(Font.Trakke.articleBody)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: .Trakke.sm) {
                        Text("\u{2022}")
                            .font(Font.Trakke.articleBody)
                            .foregroundStyle(Color.Trakke.textTertiary)
                        inlineText(item)
                            .font(Font.Trakke.articleBody)
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: .Trakke.sm) {
                        Text("\(index + 1).")
                            .font(Font.Trakke.articleBody)
                            .foregroundStyle(Color.Trakke.textTertiary)
                            .frame(minWidth: 20, alignment: .trailing)
                        inlineText(item)
                            .font(Font.Trakke.articleBody)
                    }
                }
            }

        case .table(let headers, let rows):
            MarkdownTableView(headers: headers, rows: rows)

        case .image, .speciesImage:
            EmptyView()
        }
    }

    private func inlineText(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }
}
