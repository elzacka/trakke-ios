import SwiftUI
import OSLog

/// Displays the user guide fetched from GitHub.
/// Content updates automatically when Brukerveiledning.md is updated in the repo.
struct UserGuideSheet: View {
    @State private var markdown: String?
    @State private var isLoading = true

    private static let remoteURL = URL(
        string: "https://raw.githubusercontent.com/elzacka/trakke-ios/main/Brukerveiledning.md"
    )!

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let markdown, !markdown.isEmpty {
                    UserGuideBodyView(markdown: markdown)
                } else {
                    ContentUnavailableView(
                        String(localized: "userguide.unavailable"),
                        systemImage: "doc.text",
                        description: Text(String(localized: "userguide.unavailable.detail"))
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "userguide.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadGuide()
        }
    }

    private func loadGuide() async {
        do {
            let data = try await APIClient.fetchData(url: Self.remoteURL, timeout: 10, optional: true)
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                markdown = text
                isLoading = false
                return
            }
        } catch {
            Logger.knowledge.warning("Failed to fetch remote user guide: \(error.localizedDescription)")
        }

        if let bundleURL = Bundle.main.url(forResource: "Brukerveiledning", withExtension: "md"),
           let text = try? String(contentsOf: bundleURL, encoding: .utf8) {
            markdown = text
        }
        isLoading = false
    }
}

// MARK: - User Guide Body View

/// Renders the user guide as a single continuous scroll with section headings as landmarks.
private struct UserGuideBodyView: View {
    let markdown: String
    @State private var parsedBlocks: [MarkdownBlock]?
    @State private var showBackToTop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let topID = "guide-top"
    private static let parseOptions = MarkdownParserOptions(
        skipH1: true,
        skipTableOfContents: true,
        parseAnchors: true
    )

    var body: some View {
        let blocks = parsedBlocks ?? []

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: .Trakke.md) {
                    Color.clear.frame(height: 0).id(Self.topID)

                    ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                        blockView(block)
                            .id(anchorID(for: block) ?? "block-\(index)")
                    }

                    Spacer(minLength: .Trakke.xxl)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("guideScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "guideScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                let shouldShow = offset < -300
                if shouldShow != showBackToTop {
                    withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                        showBackToTop = shouldShow
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showBackToTop {
                    Button {
                        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                            proxy.scrollTo(Self.topID, anchor: .top)
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.brand)
                            .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))
                            .trakkeControlShadow()
                    }
                    .padding(.trailing, .Trakke.sheetHorizontal)
                    .padding(.bottom, .Trakke.lg)
                    .transition(.opacity)
                    .accessibilityLabel(String(localized: "userguide.backToTop"))
                }
            }
        }
        .task(id: markdown) {
            parsedBlocks = MarkdownParser.parse(markdown, options: Self.parseOptions)
        }
    }

    private func anchorID(for block: MarkdownBlock) -> String? {
        if case .heading2(_, let anchor) = block { return anchor }
        return nil
    }

    // MARK: - Block Views

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

        case .image, .speciesImage:
            EmptyView()  // User guide does not contain images
        }
    }

    // MARK: - Inline Formatting

    private func inlineText(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }
}

// MARK: - Scroll Offset Tracking

private struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
