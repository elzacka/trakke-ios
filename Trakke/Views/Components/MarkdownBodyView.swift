import SwiftUI

/// Renders simple markdown content (headers, bullets, numbered lists, bold/italic, paragraphs, images)
/// into native SwiftUI views. Avoids third-party dependencies.
///
/// Supports two image types:
/// - Asset catalog: `![caption](asset-name)` -- loads from Xcode assets
/// - Species: `![caption](species:Scientific Name)` -- fetches from Artsdatabanken
struct MarkdownBodyView: View {
    let markdown: String
    var imageService: ArtsdatabankenImageProviding = ArtsdatabankenImageService.default
    @State private var selectedImage: ImageRef?
    @State private var parsedBlocks: [MarkdownBlock]?

    private struct ImageRef: Identifiable {
        let id: String
        let caption: String
        let isSpecies: Bool
        var loadedImage: UIImage?
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
        }
        .fullScreenCover(item: $selectedImage) { ref in
            if ref.isSpecies, let uiImage = ref.loadedImage {
                ImageViewerView(
                    uiImage: uiImage,
                    caption: ref.caption,
                    attribution: String(localized: "image.attribution.artsdatabanken")
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
                .padding(.top, .Trakke.sm)

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

        case .image(let name, let caption):
            Button {
                selectedImage = ImageRef(id: name, caption: caption, isSpecies: false)
            } label: {
                VStack(alignment: .leading, spacing: .Trakke.xs) {
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))

                    if !caption.isEmpty {
                        Text(caption)
                            .font(Font.Trakke.captionSoft)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(caption)
            .accessibilityAddTraits(.isImage)
            .accessibilityHint(String(localized: "image.fullscreen.hint"))

        case .speciesImage(let scientificName, let caption):
            SpeciesImageBlock(
                scientificName: scientificName,
                caption: caption,
                imageService: imageService,
                onTap: { loadedImage in
                    selectedImage = ImageRef(id: scientificName, caption: caption, isSpecies: true, loadedImage: loadedImage)
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
    var imageService: ArtsdatabankenImageProviding = ArtsdatabankenImageService.default
    let onTap: (UIImage) -> Void
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        if let image {
            Button { onTap(image) } label: {
                VStack(alignment: .leading, spacing: .Trakke.xs) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))

                    speciesCaption
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(caption)
            .accessibilityAddTraits(.isImage)
            .accessibilityHint(String(localized: "image.fullscreen.hint"))
        } else if isLoading {
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                RoundedRectangle(cornerRadius: .TrakkeRadius.md)
                    .fill(Color(.systemGray6))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .accessibilityLabel(String(localized: "common.loading"))
                    }

                speciesCaption
            }
            .task(id: scientificName) {
                image = await imageService.image(for: scientificName)
                isLoading = false
            }
        }
        // If not loading and no image: show nothing (species image not available)
    }

    private var speciesCaption: some View {
        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
            if !caption.isEmpty {
                Text(caption)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
            Text(String(localized: "image.attribution.artsdatabanken"))
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
    }
}

// MARK: - Markdown Table View

struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(Font.Trakke.bodyMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, .Trakke.xs)
                        .padding(.horizontal, .Trakke.sm)
                }
            }
            .background(Color.Trakke.brandTint)

            Divider()

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 {
                    Divider()
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.prefix(headers.count).enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(Font.Trakke.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, .Trakke.xs)
                            .padding(.horizontal, .Trakke.sm)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: .TrakkeRadius.md)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}
