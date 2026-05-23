import SwiftUI

struct InfoSheet: View {
    var isEmbedded = false
    /// Inline-modus: ingen ScrollView/NavigationStack/title — kalleren
    /// (f.eks. Info-fanen) håndterer scroll og NavigationStack.
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

    private var infoContent: some View {
        ScrollView {
            contentVStack
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "info.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var contentVStack: some View {
        VStack(spacing: .Trakke.cardGap) {
            // MARK: - 1. Kom i gang
            //
            // To akkordeoner deler samme kort under én tittel. Bruker
            // bare-modus av ExpandableSection slik at de ikke får hvert
            // sitt kort. Markdown rendres inline i parent-scrollen —
            // ingen push, ingen sheet-stack, ingen skjermoverganger.
            CardSection(String(localized: "info.section.gettingStarted")) {
                ExpandableSection(
                    String(localized: "userguide.title"),
                    bare: true
                ) {
                    UserGuideSheet(embedded: true)
                }

                Divider().padding(.leading, .Trakke.dividerLeading)

                ExpandableSection(
                    String(localized: "info.privacy.policy"),
                    bare: true
                ) {
                    PrivacySheet(embedded: true)
                }
            }

            // MARK: - 2. Om appen
            //
            // Statisk identitet — plassert i midten slik at versjon synes
            // uten å scrolle, og gir et visuelt anker mellom de fire
            // akkordeonene over og under.
            CardSection(String(localized: "info.appInfo")) {
                TrakkeMenuRow(
                    label: String(localized: "info.version"),
                    accessibilityValue: appVersion,
                    trailing: { TrakkeMenuRowValue(value: appVersion) }
                )
                Divider().padding(.leading, .Trakke.dividerLeading)
                TrakkeMenuRow(
                    label: String(localized: "info.developer"),
                    accessibilityValue: "Tazk",
                    trailing: { TrakkeMenuRowValue(value: "Tazk") }
                )
                Divider().padding(.leading, .Trakke.dividerLeading)
                Link(destination: URL(string: "https://github.com/elzacka/trakke-ios")!) {
                    TrakkeMenuRow(
                        label: String(localized: "info.sourceCode"),
                        trailing: { TrakkeMenuRowExternal() }
                    )
                }
                .accessibilityHint(String(localized: "accessibility.opensExternalLink"))
            }

            // MARK: - 3. Datagrunnlag og kode
            //
            // To akkordeoner i samme kort. Rekkefølgen i Datakilder
            // følger README: grunnkart først (Kartverket), deretter
            // utvidelser, tjenester, POI-leverandører, og til slutt
            // OpenStreetMap som samle-kilde.
            CardSection(String(localized: "info.section.attribution")) {
                ExpandableSection(
                    String(localized: "info.dataSources"),
                    bare: true
                ) {
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
                            name: "Stadia Maps / Valhalla",
                            detail: String(localized: "info.valhalla.detail"),
                            license: "MIT / ODbL",
                            attributionURL: URL(string: "https://stadiamaps.com/attribution/")
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

                Divider().padding(.leading, .Trakke.dividerLeading)

                ExpandableSection(
                    String(localized: "info.openSource"),
                    bare: true
                ) {
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
            }

            Spacer(minLength: .Trakke.lg)
        }
        .padding(.horizontal, inline ? 0 : .Trakke.sheetHorizontal)
        .padding(.top, inline ? 0 : .Trakke.sheetTop)
    }

    // MARK: - Data source row
    //
    // Tre-linjers anatomi: navn (eventuelt som lenke), kort detalj og en
    // lisens-pill. Pillen gjør det enkelt å skanne lisensvilkår uten å lese
    // hver rad i detalj. arrow.up.right vises kun på rader som faktisk har
    // ekstern attribusjons-URL.

    private func dataSourceRow(
        name: String,
        detail: String,
        license: String,
        attributionURL: URL? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
            HStack(spacing: .Trakke.sm) {
                if let url = attributionURL {
                    Link(destination: url) {
                        HStack(spacing: .Trakke.xs) {
                            Text(name)
                                .font(Font.Trakke.bodyMedium)
                                .foregroundStyle(Color.Trakke.text)
                            Image(systemName: "arrow.up.right")
                                .font(Font.Trakke.captionSoft)
                                .foregroundStyle(Color.Trakke.textSoft)
                        }
                    }
                    .accessibilityLabel(name)
                    .accessibilityHint(String(localized: "accessibility.opensExternalLink"))
                } else {
                    Text(name)
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.text)
                }
                Spacer()
                licensePill(license)
            }
            Text(detail)
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .Trakke.sm)
    }

    private func licensePill(_ license: String) -> some View {
        Text(license)
            .font(Font.Trakke.captionSoft)
            .foregroundStyle(Color.Trakke.textSecondary)
            .padding(.horizontal, .Trakke.badgePadH)
            .padding(.vertical, .Trakke.badgePadV)
            .background(Color.Trakke.brandTint)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
            .accessibilityLabel(String(localized: "info.license") + ": " + license)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
