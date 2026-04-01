import SwiftUI
import CoreLocation

struct KnowledgeDetailSheet: View {
    let entry: KnowledgeEntry
    var onNavigate: ((CLLocationCoordinate2D) -> Void)?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                    themeLabel
                    descriptionCard
                    attributesCard
                    coordinatesCard
                    sourceLinkCard
                    navigateButton
                    sourceAttribution

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let theme = entry.knowledgeTheme {
                        Image(systemName: theme.iconName)
                            .foregroundStyle(Color(hex: theme.color))
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    // MARK: - Theme

    @ViewBuilder
    private var themeLabel: some View {
        if let theme = entry.knowledgeTheme {
            Text(theme.displayName)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionCard: some View {
        if let description = entry.description, !description.isEmpty {
            CardSection(String(localized: "knowledge.description")) {
                Text(description)
                    .font(Font.Trakke.bodyRegular)
                    .padding(.vertical, .Trakke.xs)
            }
        }
    }

    // MARK: - Attributes

    @ViewBuilder
    private var attributesCard: some View {
        if !entry.attributesDictionary.isEmpty {
            CardSection(String(localized: "knowledge.details")) {
                ForEach(
                    Array(entry.attributesDictionary.sorted { $0.key < $1.key }.enumerated()),
                    id: \.element.key
                ) { index, attr in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                        Text(attr.key)
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.textTertiary)
                        Text(attr.value)
                            .font(Font.Trakke.bodyRegular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, .Trakke.rowVertical)
                }
            }
        }
    }

    // MARK: - Coordinates

    private var coordinatesCard: some View {
        CardSection(String(localized: "poi.coordinates")) {
            let formatted = CoordinateService.format(
                coordinate: entry.coordinate,
                format: .dd
            )
            HStack {
                Text(formatted.display)
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                Spacer()
                Button {
                    UIPasteboard.general.setItems(
                        [["public.utf8-plain-text": formatted.copyText]],
                        options: [.expirationDate: Date().addingTimeInterval(300)]
                    )
                    copied = true
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: String(localized: "common.copied")
                    )
                    Task {
                        try? await Task.sleep(for: .milliseconds(1500))
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.brand)
                        .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "common.copy"))
            }
        }
    }

    // MARK: - Source Link

    @ViewBuilder
    private var sourceLinkCard: some View {
        if let sourceURLString = entry.sourceURL,
           let url = URL(string: sourceURLString),
           url.scheme == "https" {
            CardSection {
                Link(destination: url) {
                    HStack {
                        Text(String(localized: "poi.moreInfo"))
                            .font(Font.Trakke.bodyRegular)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(Font.Trakke.captionSoft)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                    .padding(.vertical, .Trakke.labelGap)
                }
            }
        }
    }

    // MARK: - Navigate

    private var navigateButton: some View {
        Button {
            onNavigate?(entry.coordinate)
        } label: {
            Label(String(localized: "navigation.navigateHere"), systemImage: "location.north.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.trakkePrimary)
    }

    // MARK: - Source Attribution

    private var sourceAttribution: some View {
        HStack(spacing: .Trakke.xs) {
            Text(String(localized: "poi.source"))
            Text(entry.source)
            if let theme = entry.knowledgeTheme {
                Text("(\(theme.sourceLicense))")
            }
        }
        .font(Font.Trakke.caption)
        .foregroundStyle(Color.Trakke.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .Trakke.xs)
    }
}
