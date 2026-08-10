import SwiftUI

/// Renders simple markdown content (headers, bullets, numbered lists, bold/italic, paragraphs, images)
/// into native SwiftUI views. Avoids third-party dependencies.
///
/// Supports two image types:
/// - Asset catalog: `![caption](asset-name)` -- loads from Xcode assets
/// - Species: `![caption](species:Scientific Name)` -- fetches from Artsdatabanken
/// Identiteten til en h2-overskrift, slik at en visning utenfor artikkelen kan
/// scrolle til den. Nøkkelen er selve overskriftsteksten som står i artikkelen.
struct MarkdownHeadingAnchor: Hashable {
    let heading: String
}

struct MarkdownBodyView: View {
    let markdown: String
    var imageService: ArtsdatabankenImageService = ArtsdatabankenImageService.default
    /// Kalles når markdown er parset og overskriftene finnes i visningstreet.
    /// `ArticleDetailView` scroller til et avsnitt herfra – en `scrollTo` før
    /// dette finner ingen id, fordi blokkene ennå ikke er lagt ut.
    var onParsed: (() -> Void)? = nil
    @State private var selectedImage: ImageRef?
    @State private var parsedBlocks: [MarkdownBlock]?

    private struct ImageRef: Identifiable {
        let id: String
        let caption: String
        let isSpecies: Bool
        var loadedImage: UIImage?
        /// Krediteringen bildet ble vist med – bundlede Commons-bilder har
        /// fotograf og lisens som må følge bildet også i fullskjerm.
        var attribution: String?
        var name: String { id }
    }

    private static let parseOptions = MarkdownParserOptions(parseImages: true)

    var body: some View {
        VStack(alignment: .leading, spacing: .Trakke.md) {
            ForEach(Array((parsedBlocks ?? []).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .task(id: markdown) {
            parsedBlocks = MarkdownParser.parse(markdown, options: Self.parseOptions)
            // Ett hopp i kjøresløyfa før varselet: blokkene er satt, men ikke
            // lagt ut, og en scrollTo i samme steg treffer ingenting.
            await Task.yield()
            onParsed?()
        }
        .fullScreenCover(item: $selectedImage) { ref in
            if ref.isSpecies, let uiImage = ref.loadedImage {
                ImageViewerView(
                    uiImage: uiImage,
                    caption: ref.caption,
                    attribution: ref.attribution ?? String(localized: "image.attribution.artsdatabanken")
                )
            } else if !ref.isSpecies {
                ImageViewerView(name: ref.name, caption: ref.caption)
            }
        }
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading2(let text, _):
            inlineText(text)
                .font(Font.Trakke.articleHeading)
                .padding(.top, .Trakke.xl)
                .id(MarkdownHeadingAnchor(heading: text))

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

        case .image(let name, let caption):
            Button {
                selectedImage = ImageRef(id: name, caption: caption, isSpecies: false)
            } label: {
                VStack(alignment: .leading, spacing: .Trakke.xs) {
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))

                    if !caption.isEmpty {
                        Text(caption)
                            .font(Font.Trakke.articleCaption)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            // Bilder uten bildetekst (overskriften rett over beskriver dem)
            // skal fortsatt ha en VoiceOver-etikett.
            .accessibilityLabel(caption.isEmpty ? String(localized: "image.accessibility.fallback") : caption)
            .accessibilityAddTraits(.isImage)
            .accessibilityHint(String(localized: "image.fullscreen.hint"))

        case .speciesImage(let scientificName, let caption):
            SpeciesImageBlock(
                scientificName: scientificName,
                caption: caption,
                imageService: imageService,
                onTap: { loadedImage, attribution in
                    selectedImage = ImageRef(
                        id: scientificName,
                        caption: caption,
                        isSpecies: true,
                        loadedImage: loadedImage,
                        attribution: attribution
                    )
                }
            )
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

// MARK: - Species Image Block (async loading)

private struct SpeciesImageBlock: View {
    let scientificName: String
    let caption: String
    var imageService: ArtsdatabankenImageService = ArtsdatabankenImageService.default
    /// Bildet og krediteringen det ble vist med, så fullskjermvisningen
    /// aldri viser feil fotograf.
    let onTap: (UIImage, String) -> Void
    @State private var image: UIImage?
    @State private var isLoading = true

    /// Bundlet reservebilde for arter Artsdatabanken-katalogen mangler.
    private var bundled: BundledSpeciesImage? {
        BundledSpeciesImage.byScientificName[scientificName]
    }

    var body: some View {
        if let bundled, let bundledImage = UIImage(named: bundled.assetName) {
            imageBlock(bundledImage, attribution: bundled.credit)
        } else if let image {
            imageBlock(image, attribution: String(localized: "image.attribution.artsdatabanken"))
        } else if isLoading {
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                RoundedRectangle(cornerRadius: .TrakkeRadius.lg)
                    .fill(Color(.systemGray6))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .accessibilityLabel(String(localized: "common.loading"))
                    }

                speciesCaption(String(localized: "image.attribution.artsdatabanken"))
            }
            .task(id: scientificName) {
                image = await imageService.image(for: scientificName)
                isLoading = false
            }
        }
        // If not loading and no image: show nothing (species image not available)
    }

    private func imageBlock(_ uiImage: UIImage, attribution: String) -> some View {
        Button { onTap(uiImage, attribution) } label: {
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))

                speciesCaption(attribution)
            }
        }
        .buttonStyle(.plain)
        // Bilder uten bildetekst (overskriften rett over beskriver dem)
        // skal fortsatt ha en VoiceOver-etikett.
        .accessibilityLabel(caption.isEmpty ? String(localized: "image.accessibility.fallback") : caption)
        .accessibilityAddTraits(.isImage)
        .accessibilityHint(String(localized: "image.fullscreen.hint"))
    }

    private func speciesCaption(_ attribution: String) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
            if !caption.isEmpty {
                Text(caption)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
            Text(attribution)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
    }
}

// MARK: - Markdown Table View

/// Renders a markdown table in one of two layouts.
///
/// **Why two.** An iPhone sheet gives the content about 340 pt. Split four ways
/// that leaves roughly 65 pt of text per column, which is narrower than the
/// words going into it: «Kartverket (cache.kartverket.no)» came out hyphenated
/// across five lines as «Kartver-ket (cache.-kartver-ket.no)». A column that
/// cannot fit one word is not a column.
///
/// So a table with three or more columns is stacked instead: one block per row,
/// the first cell as its heading, the rest as label-and-value pairs. Nothing is
/// dropped or truncated — the same cells are simply laid out down the screen
/// rather than across it. Two-column tables are the common case (33 of the 41
/// tables in the bundled articles) and stay side by side, because a label and
/// its value read well in two narrow columns.
///
/// At accessibility text sizes even two columns stop fitting, so those stack too.
struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isStacked: Bool {
        headers.count >= 3 || dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        Group {
            if isStacked {
                stackedLayout
            } else {
                gridLayout
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: .TrakkeRadius.lg)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: - Stacked (3+ columns, or accessibility sizes)

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 {
                    Divider()
                }
                stackedRow(row)
            }
        }
    }

    private func stackedRow(_ row: [String]) -> some View {
        // The first cell names the thing the row is about, so it becomes the
        // heading. The remaining cells pair with their own column header, which
        // is what replaces the header row the stacked layout has no room for.
        VStack(alignment: .leading, spacing: .Trakke.sm) {
            if let first = row.first {
                Self.markdownText(first)
                    .font(Font.Trakke.bodyRegular.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(Array(row.dropFirst().prefix(max(headers.count - 1, 0)).enumerated()), id: \.offset) { index, cell in
                let trimmed = cell.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                        Self.markdownText(headers[index + 1])
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.textSecondary)
                        Self.markdownText(trimmed)
                            .font(Font.Trakke.bodyRegular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, .Trakke.cardPadV)
        .padding(.horizontal, .Trakke.cardPadH)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Grid (2 columns)

    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Self.markdownText(header)
                        .font(Font.Trakke.bodyRegular.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, .Trakke.rowVertical)
                        .padding(.horizontal, .Trakke.sm)
                }
            }
            .background(Color.Trakke.brandTint)

            Divider()

            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 {
                    Divider()
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.prefix(headers.count).enumerated()), id: \.offset) { _, cell in
                        Self.markdownText(cell)
                            .font(Font.Trakke.bodyRegular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, .Trakke.rowVertical)
                            .padding(.horizontal, .Trakke.sm)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private static func markdownText(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }
}
