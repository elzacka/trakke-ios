import SwiftUI
import OSLog

/// In-app rendering of the privacy policy. Mirrors the pattern used by
/// UserGuideSheet: fetch the live `PERSONVERN.md` from the GitHub repo so users
/// see updates between app releases, with the bundled copy as offline fallback.
struct PrivacySheet: View {
    @State private var markdown: String?
    @State private var isLoading = true

    private static let remoteURL = URL(
        string: "https://raw.githubusercontent.com/elzacka/trakke-ios/main/PERSONVERN.md"
    )!

    var body: some View {
        NavigationStack {
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
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "info.privacy.policy"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadPrivacy()
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
    @State private var parsedBlocks: [MarkdownBlock]?

    private static let parseOptions = MarkdownParserOptions(
        skipH1: true,
        skipTableOfContents: false,
        parseAnchors: false
    )

    var body: some View {
        let blocks = parsedBlocks ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: .Trakke.md) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
                Spacer(minLength: .Trakke.xxl)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .task(id: markdown) {
            parsedBlocks = MarkdownParser.parse(markdown, options: Self.parseOptions)
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
                .font(Font.Trakke.bodyMedium)
                .padding(.top, .Trakke.xs)

        case .paragraph(let text):
            inlineText(text)
                .font(Font.Trakke.bodyRegular)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: .Trakke.sm) {
                        Text("\u{2022}")
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.textTertiary)
                        inlineText(item)
                            .font(Font.Trakke.bodyRegular)
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: .Trakke.sm) {
                        Text("\(index + 1).")
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.textTertiary)
                            .frame(minWidth: 20, alignment: .trailing)
                        inlineText(item)
                            .font(Font.Trakke.bodyRegular)
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
