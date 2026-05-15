import SwiftUI

struct InfoSheet: View {
    var isEmbedded = false
    /// Inline-modus: ingen ScrollView/NavigationStack/title — kalleren
    /// (f.eks. accordion-vert i Mer-fanen) håndterer scroll og kontekst.
    var inline = false

    var body: some View {
        if inline {
            contentVStack
        } else if isEmbedded {
            infoContent
        } else {
            NavigationStack {
                infoContent
            }
        }
    }

    @State private var showUserGuide = false
    @State private var showPrivacySheet = false

    private var infoContent: some View {
        ScrollView {
            contentVStack
        }
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "info.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUserGuide) {
            UserGuideSheet()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacySheet()
                .presentationDragIndicator(.visible)
        }
    }

    private var contentVStack: some View {
        VStack(spacing: .Trakke.cardGap) {
                    // MARK: - User Guide & Links (uten pynt-ikoner)
                    CardSection {
                        infoMenuButton(label: String(localized: "userguide.title"), trailing: .chevron) {
                            showUserGuide = true
                        }

                        Divider().padding(.leading, .Trakke.dividerLeading)

                        infoMenuButton(label: String(localized: "info.privacy.policy"), trailing: .chevron) {
                            showPrivacySheet = true
                        }

                        Divider().padding(.leading, .Trakke.dividerLeading)

                        Link(destination: URL(string: "https://github.com/elzacka/trakke-ios")!) {
                            HStack(spacing: .Trakke.md) {
                                Text(String(localized: "info.sourceCode"))
                                    .font(Font.Trakke.bodyRegular)
                                    .foregroundStyle(Color.Trakke.text)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(Font.Trakke.captionSoft)
                                    .foregroundStyle(Color.Trakke.textTertiary)
                            }
                            .frame(minHeight: .Trakke.touchMin)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel(String(localized: "info.sourceCode"))
                        .accessibilityHint(String(localized: "accessibility.opensExternalLink"))
                    }

                    // MARK: - Data Sources
                    //
                    // Rekkefølgen følger README: grunnkart først (Kartverket),
                    // deretter kart-utvidelser (terreng, vern), så tjenester
                    // (rute, vær, varsler), så spesifikke POI-leverandører,
                    // og til slutt OpenStreetMap som samle-kilde for resten.
                    ExpandableSection(String(localized: "info.dataSources")) {
                        VStack(spacing: 0) {
                        dataSourceRow(
                            name: "Kartverket",
                            detail: String(localized: "info.kartverket.detail"),
                            license: "NLOD 2.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Mapzen Terrain Tiles",
                            detail: String(localized: "info.mapzen.detail"),
                            license: "CC BY 4.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Milj\u{00F8}direktoratet",
                            detail: String(localized: "info.miljodir.detail"),
                            license: "NLOD 2.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "FOSSGIS / Valhalla",
                            detail: String(localized: "info.valhalla.detail"),
                            license: "MIT / ODbL"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Meteorologisk institutt",
                            detail: String(localized: "info.met.detail"),
                            license: "CC BY 4.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Yr/NRK",
                            detail: String(localized: "info.yr.detail"),
                            license: "CC BY 4.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Havvarsel-Frost",
                            detail: String(localized: "info.havvarsel.detail"),
                            license: "CC BY 4.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "NVE / Varsom",
                            detail: String(localized: "info.nve.detail"),
                            license: "NLOD"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Artsdatabanken",
                            detail: String(localized: "info.artsdatabanken.detail"),
                            license: "CC BY 4.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Riksantikvaren",
                            detail: String(localized: "info.ra.detail"),
                            license: "NLOD"
                        )
                        Divider()
                        dataSourceRow(
                            name: "DSB",
                            detail: String(localized: "info.dsb.detail"),
                            license: "NLOD"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Wikidata",
                            detail: String(localized: "info.wikidata.detail"),
                            license: "CC0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "UT.no/DNT, Statskog m.fl.",
                            detail: String(localized: "info.utno.detail"),
                            license: "ODbL / NLOD"
                        )
                        Divider()
                        dataSourceRow(
                            name: "OpenStreetMap-bidragsytere",
                            detail: String(localized: "info.osm.detail"),
                            license: "ODbL"
                        )
                        }
                    }

                    // MARK: - Open Source (alphabetical, expandable)
                    ExpandableSection(String(localized: "info.openSource")) {
                        VStack(spacing: 0) {
                            dataSourceRow(
                                name: "GRDB",
                                detail: String(localized: "info.grdb.detail"),
                                license: "MIT"
                            )
                            Divider()
                            dataSourceRow(
                                name: "MapLibre",
                                detail: String(localized: "info.maplibre.detail"),
                                license: "BSD / ISC"
                            )
                            Divider()
                            dataSourceRow(
                                name: "Material Symbols",
                                detail: String(localized: "info.materialsymbols.detail"),
                                license: "Apache 2.0"
                            )
                            Divider()
                            dataSourceRow(
                                name: "Tabler Icons",
                                detail: String(localized: "info.tabler.detail"),
                                license: "MIT"
                            )
                        }
                    }

                    // MARK: - App Info
                    CardSection(String(localized: "info.appInfo")) {
                        infoRow(
                            label: String(localized: "info.version"),
                            value: appVersion
                        )
                        Divider().padding(.leading, .Trakke.dividerLeading)
                        infoRow(
                            label: String(localized: "info.developer"),
                            value: "Tazk"
                        )
                    }

            Spacer(minLength: .Trakke.lg)
        }
        .padding(.horizontal, inline ? 0 : .Trakke.sheetHorizontal)
        .padding(.top, inline ? 0 : .Trakke.sheetTop)
    }

    // MARK: - Data Source Row

    private func dataSourceRow(
        name: String,
        detail: String,
        license: String
    ) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
            HStack {
                Text(name)
                    .font(Font.Trakke.bodyMedium)
                Spacer()
                Text(license)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.Trakke.brandTint)
                    .clipShape(Capsule())
            }
            Text(detail)
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.vertical, .Trakke.rowVertical)
    }

    // MARK: - Info Row

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Font.Trakke.bodyRegular)
            Spacer()
            Text(value)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.vertical, .Trakke.rowVertical)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Menu row (uten ledende ikon)

    private enum TrailingGlyph {
        case chevron
    }

    private func infoMenuButton(
        label: String,
        trailing: TrailingGlyph,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: .Trakke.md) {
                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)
                Spacer()
                switch trailing {
                case .chevron:
                    Image(systemName: "chevron.right")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
