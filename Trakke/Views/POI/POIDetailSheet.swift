import SwiftUI

struct POIDetailSheet: View {
    let poi: POI
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: poi.category.iconName)
                            .font(.title2)
                            .foregroundStyle(Color(hex: poi.category.color))
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(poi.name)
                                .font(.headline)
                            Text(poi.category.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !poi.details.isEmpty {
                    Section(String(localized: "poi.details")) {
                        ForEach(sortedDetails, id: \.key) { key, value in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localizedDetailKey(key))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(value)
                                    .font(.body)
                            }
                        }
                    }
                }

                Section(String(localized: "poi.coordinates")) {
                    let formatted = CoordinateService.format(
                        coordinate: poi.coordinate,
                        format: .dd
                    )
                    HStack {
                        Text(formatted.display)
                            .font(.body.monospacedDigit())
                        Spacer()
                        Button {
                            UIPasteboard.general.string = formatted.copyText
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }

                if let link = poi.details["link"], let url = URL(string: link) {
                    Section {
                        Link(destination: url) {
                            HStack {
                                Text(String(localized: "poi.moreInfo"))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                        }
                    }
                }
            }
            .navigationTitle(poi.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var sortedDetails: [(key: String, value: String)] {
        poi.details
            .filter { $0.key != "link" }
            .sorted { $0.key < $1.key }
    }

    private func localizedDetailKey(_ key: String) -> String {
        switch key {
        case "address": return String(localized: "poi.detail.address")
        case "capacity": return String(localized: "poi.detail.capacity")
        case "category": return String(localized: "poi.detail.category")
        case "description": return String(localized: "poi.detail.description")
        case "height": return String(localized: "poi.detail.height")
        case "operator": return String(localized: "poi.detail.operator")
        case "inscription": return String(localized: "poi.detail.inscription")
        case "period": return String(localized: "poi.detail.period")
        case "shelterType": return String(localized: "poi.detail.shelterType")
        case "municipality": return String(localized: "poi.detail.municipality")
        case "county": return String(localized: "poi.detail.county")
        default: return key
        }
    }
}
