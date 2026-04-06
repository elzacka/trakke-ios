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

    @State private var showUserGuide = false

    private var infoContent: some View {
        ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    // MARK: - User Guide & Links
                    CardSection {
                        Button {
                            showUserGuide = true
                        } label: {
                            HStack(spacing: .Trakke.md) {
                                Image(systemName: "book.pages")
                                    .font(Font.Trakke.bodyMedium)
                                    .foregroundStyle(Color.Trakke.brand)
                                    .frame(width: .Trakke.touchMin)
                                    .accessibilityHidden(true)

                                Text(String(localized: "userguide.title"))
                                    .font(Font.Trakke.bodyRegular)
                                    .foregroundStyle(Color.Trakke.text)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(Font.Trakke.captionSoft)
                                    .foregroundStyle(Color.Trakke.textTertiary)
                            }
                            .frame(minHeight: .Trakke.touchMin)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Link(destination: URL(string: "https://github.com/elzacka/trakke-ios/blob/main/PERSONVERN.md")!) {
                            HStack(spacing: .Trakke.md) {
                                Image(systemName: "hand.raised")
                                    .font(Font.Trakke.bodyMedium)
                                    .foregroundStyle(Color.Trakke.brand)
                                    .frame(width: .Trakke.touchMin)
                                    .accessibilityHidden(true)

                                Text(String(localized: "info.privacy.policy"))
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
                        .accessibilityLabel(String(localized: "info.privacy.policy"))

                        Divider()

                        Link(destination: URL(string: "https://github.com/elzacka/trakke-ios")!) {
                            HStack(spacing: .Trakke.md) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(Font.Trakke.bodyMedium)
                                    .foregroundStyle(Color.Trakke.brand)
                                    .frame(width: .Trakke.touchMin)
                                    .accessibilityHidden(true)

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
                    }

                    // MARK: - Data Sources (alphabetical)
                    CardSection(String(localized: "info.dataSources")) {
                        dataSourceRow(
                            name: "Artsdatabanken",
                            detail: String(localized: "info.artsdatabanken.detail"),
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
                            name: "FOSSGIS / Valhalla",
                            detail: String(localized: "info.valhalla.detail"),
                            license: "ODbL / MIT"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Havvarsel-Frost",
                            detail: String(localized: "info.havvarsel.detail"),
                            license: "CC BY 4.0"
                        )
                        Divider()
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
                            name: "MET Norway",
                            detail: String(localized: "info.met.detail"),
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
                            name: "NVE / Varsom",
                            detail: String(localized: "info.nve.detail"),
                            license: "NLOD 2.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "OpenStreetMap",
                            detail: String(localized: "info.osm.detail"),
                            license: "ODbL"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Riksantikvaren",
                            detail: String(localized: "info.ra.detail"),
                            license: "NLOD"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Yr/NRK",
                            detail: String(localized: "info.yr.detail"),
                            license: "CC BY 4.0"
                        )
                    }

                    // MARK: - Open Source (alphabetical)
                    CardSection(String(localized: "info.openSource")) {
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
                            name: "NGA",
                            detail: String(localized: "info.nga.detail"),
                            license: "MIT"
                        )
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
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "info.title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showUserGuide) {
                UserGuideSheet()
                    .presentationDragIndicator(.visible)
            }
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
