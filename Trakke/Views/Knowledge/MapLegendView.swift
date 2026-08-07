import SwiftUI

/// Tegnforklaring for kartet – Kartverkets symboler med zoomnivået de
/// vises fra. Pushes fra Kunnskap-fanen.
struct MapLegendView: View {
    var body: some View {
        TrakkePushedPage(title: String(localized: "legend.title")) {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    introCard

                    ForEach(MapLegend.sections) { section in
                        legendSection(section)
                    }

                    // CC BY 4.0 krever at bearbeiding angis og at lisensen
                    // lenkes – utsnittene er beskårne, så begge deler står her.
                    VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                        Text(String(localized: "legend.attribution"))
                            .foregroundStyle(Color.Trakke.textTertiary)
                        Link(destination: URL(string: "https://creativecommons.org/licenses/by/4.0/deed.no")!) {
                            Text(verbatim: "creativecommons.org/licenses/by/4.0")
                        }
                        .accessibilityHint(String(localized: "accessibility.opensExternalLink"))
                    }
                    .font(Font.Trakke.captionSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .Trakke.xs)

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
        }
    }

    // MARK: - Intro

    private var introCard: some View {
        ExpandableSection(String(localized: "legend.intro.header")) {
            VStack(spacing: 0) {
                Text(String(localized: "legend.intro"))
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, .Trakke.rowVertical)

                Divider().padding(.leading, .Trakke.dividerLeading)

                ForEach(Array(MapLegend.detailLevels.enumerated()), id: \.offset) { index, level in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    HStack {
                        Text(String(localized: String.LocalizationValue(level.nameKey)))
                            .font(Font.Trakke.bodyRegular)
                        Spacer()
                        Text(level.range)
                            .font(Font.Trakke.bodyRegular.monospacedDigit())
                            .foregroundStyle(Color.Trakke.textSoft)
                    }
                    .padding(.vertical, .Trakke.rowVertical)
                    .accessibilityElement(children: .combine)
                }

                Divider().padding(.leading, .Trakke.dividerLeading)

                // Fotnoter: dempet og mindre enn brødteksten.
                VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                    Text(String(localized: "legend.footnote.n50"))
                    Text(String(localized: "legend.footnote.fkb"))
                }
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .Trakke.rowVertical)
            }
        }
    }

    // MARK: - Sections

    private func legendSection(_ section: MapLegendSection) -> some View {
        CardSection(section.title) {
            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    legendRow(row)
                }

                if let footnote = section.footnote {
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    Text(footnote)
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, .Trakke.rowVertical)
                }
            }
        }
    }

    private func legendRow(_ row: MapLegendRow) -> some View {
        HStack(spacing: .Trakke.md) {
            Image(row.asset)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(row.name)
                    .font(Font.Trakke.bodyRegular)
                if let detail = row.detail {
                    Text(detail)
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
            }

            Spacer()

            if let zoom = row.fromZoom {
                Text(String(localized: "legend.fromZoom \(zoom)"))
                    .font(Font.Trakke.caption.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textSoft)
            }
        }
        .padding(.vertical, .Trakke.rowVertical)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        MapLegendView()
    }
}
