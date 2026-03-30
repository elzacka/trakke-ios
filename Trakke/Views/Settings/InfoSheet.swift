import SwiftUI

struct InfoSheet: View {
    var isEmbedded = false

    var body: some View {
        if isEmbedded {
            infoContent
        } else {
            NavigationStack {
                infoContent
            }
        }
    }

    private var infoContent: some View {
        ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    // MARK: - Data Sources
                    CardSection(String(localized: "info.dataSources")) {
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
                            name: "MET Norway",
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
                            name: "DSB",
                            detail: String(localized: "info.dsb.detail"),
                            license: "NLOD"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Riksantikvaren",
                            detail: String(localized: "info.ra.detail"),
                            license: "NLOD"
                        )
                        Divider()
                        dataSourceRow(
                            name: "OpenStreetMap",
                            detail: String(localized: "info.osm.detail"),
                            license: "ODbL"
                        )
                        Divider()
                        dataSourceRow(
                            name: "FOSSGIS / Valhalla",
                            detail: String(localized: "info.valhalla.detail"),
                            license: "ODbL / MIT"
                        )
                    }

                    // MARK: - Open Source
                    CardSection(String(localized: "info.openSource")) {
                        dataSourceRow(
                            name: "MapLibre",
                            detail: String(localized: "info.maplibre.detail"),
                            license: "BSD / ISC"
                        )
                        Divider()
                        dataSourceRow(
                            name: "NGA",
                            detail: String(localized: "info.nga.detail"),
                            license: "MIT"
                        )
                        Divider()
                        dataSourceRow(
                            name: "GRDB",
                            detail: String(localized: "info.grdb.detail"),
                            license: "MIT"
                        )
                    }

                    HStack {
                        Link(destination: URL(string: "https://github.com/elzacka/trakke-ios/blob/main/PERSONVERN.md")!) {
                            HStack(spacing: .Trakke.xs) {
                                Text(String(localized: "info.privacy.policy"))
                                Image(systemName: "arrow.up.right")
                                    .font(Font.Trakke.captionSoft)
                            }
                        }
                        .accessibilityLabel(String(localized: "info.privacy.policy"))

                        Link(destination: URL(string: "https://github.com/elzacka/trakke-ios")!) {
                            HStack(spacing: .Trakke.xs) {
                                Text(String(localized: "info.sourceCode"))
                                Image(systemName: "arrow.up.right")
                                    .font(Font.Trakke.captionSoft)
                            }
                        }
                        .accessibilityLabel(String(localized: "info.sourceCode"))

                        Spacer()
                    }
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.brand)

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
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "info.title"))
            .navigationBarTitleDisplayMode(.inline)
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
}
