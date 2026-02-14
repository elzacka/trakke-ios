import SwiftUI

struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "info.dataSources")) {
                    dataSourceGroup(
                        title: String(localized: "info.maps"),
                        items: [
                            DataSourceItem(
                                name: "Kartverket",
                                detail: String(localized: "info.kartverket.detail"),
                                license: "NLOD 2.0"
                            ),
                        ]
                    )

                    dataSourceGroup(
                        title: String(localized: "info.weather"),
                        items: [
                            DataSourceItem(
                                name: "MET Norway",
                                detail: String(localized: "info.met.detail"),
                                license: "NLOD 2.0"
                            ),
                        ]
                    )

                    dataSourceGroup(
                        title: String(localized: "info.poi"),
                        items: [
                            DataSourceItem(
                                name: "DSB",
                                detail: String(localized: "info.dsb.detail"),
                                license: "NLOD"
                            ),
                            DataSourceItem(
                                name: "OpenStreetMap",
                                detail: String(localized: "info.osm.detail"),
                                license: "ODbL"
                            ),
                            DataSourceItem(
                                name: "Riksantikvaren",
                                detail: String(localized: "info.ra.detail"),
                                license: "NLOD"
                            ),
                        ]
                    )
                }

                Section(String(localized: "info.privacy")) {
                    Label {
                        Text(String(localized: "info.privacy.noTracking"))
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.green)
                    }

                    Label {
                        Text(String(localized: "info.privacy.localData"))
                    } icon: {
                        Image(systemName: "iphone")
                            .foregroundStyle(.blue)
                    }

                    Label {
                        Text(String(localized: "info.privacy.euOnly"))
                    } icon: {
                        Image(systemName: "globe.europe.africa")
                            .foregroundStyle(.orange)
                    }
                }

                Section(String(localized: "info.appInfo")) {
                    HStack {
                        Text(String(localized: "info.version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "info.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Data Source Group

    private func dataSourceGroup(title: String, items: [DataSourceItem]) -> some View {
        DisclosureGroup(title) {
            ForEach(items, id: \.name) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.bold())
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Lisens: \(item.license)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct DataSourceItem {
    let name: String
    let detail: String
    let license: String
}
