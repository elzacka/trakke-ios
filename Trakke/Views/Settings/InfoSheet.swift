import SwiftUI

struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
                            name: "MET Norway",
                            detail: String(localized: "info.met.detail"),
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
                            name: "\u{00A9} OpenStreetMap contributors",
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
                            name: "Milj\u{00F8}direktoratet",
                            detail: String(localized: "info.miljodir.detail"),
                            license: "NLOD 2.0"
                        )
                        Divider()
                        dataSourceRow(
                            name: "Yr/NRK",
                            detail: String(localized: "info.yr.detail"),
                            license: "CC BY 4.0"
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
                    }

                    // MARK: - Privacy
                    CardSection(String(localized: "info.privacy")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "info.privacy.noTracking"))
                            Text(String(localized: "info.privacy.localData"))
                            Text(String(localized: "info.privacy.euOnly"))
                        }
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textMuted)
                        .padding(.vertical, 4)
                    }

                    HStack {
                        Link(destination: URL(string: "https://github.com/elzacka/trakke-ios/blob/main/PERSONVERN.md")!) {
                            HStack(spacing: 4) {
                                Text(String(localized: "info.privacy.policy"))
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                            }
                        }

                        Link(destination: URL(string: "https://github.com/elzacka/trakke-ios")!) {
                            HStack(spacing: 4) {
                                Text(String(localized: "info.sourceCode"))
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                            }
                        }

                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.Trakke.textSoft)

                    // MARK: - App Info
                    CardSection(String(localized: "info.appInfo")) {
                        infoRow(
                            label: String(localized: "info.version"),
                            value: appVersion
                        )
                        Divider().padding(.leading, 4)
                        infoRow(
                            label: String(localized: "info.developer"),
                            value: "Tazk"
                        )
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "info.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Data Source Row

    private func dataSourceRow(
        name: String,
        detail: String,
        license: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(license)
                    .font(.caption2)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.Trakke.brandTint)
                    .clipShape(Capsule())
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.Trakke.textSoft)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Info Row

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.Trakke.textSoft)
        }
        .padding(.vertical, 6)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
