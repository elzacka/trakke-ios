import SwiftUI

struct POIDetailSheet: View {
    let poi: POI
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                    // MARK: - Category
                    Text(poi.category.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Color.Trakke.textSoft)

                    // MARK: - Details
                    if !poi.details.isEmpty {
                        CardSection(String(localized: "poi.details")) {
                            ForEach(Array(sortedDetails.enumerated()), id: \.element.key) { index, detail in
                                if index > 0 {
                                    Divider().padding(.leading, 4)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizedDetailKey(detail.key))
                                        .font(.caption)
                                        .foregroundStyle(Color.Trakke.textSoft)
                                    Text(detail.value)
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, .Trakke.rowVertical)
                            }
                        }
                    }

                    // MARK: - Coordinates
                    CardSection(String(localized: "poi.coordinates")) {
                        let formatted = CoordinateService.format(
                            coordinate: poi.coordinate,
                            format: .dd
                        )
                        HStack {
                            Text(formatted.display)
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            Button {
                                UIPasteboard.general.string = formatted.copyText
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.Trakke.brand)
                            }
                            .accessibilityLabel(String(localized: "common.copy"))
                        }
                    }

                    // MARK: - External Link
                    if let link = poi.details["link"],
                       let url = URL(string: link),
                       url.scheme == "https" {
                        CardSection {
                            Link(destination: url) {
                                HStack {
                                    Text(String(localized: "poi.moreInfo"))
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundStyle(Color.Trakke.textSoft)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // MARK: - Data Source Attribution
                    HStack(spacing: 4) {
                        Text(String(localized: "poi.source"))
                        Text(poi.category.sourceName)
                        Text("(\(poi.category.sourceLicense))")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(poi.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(poi.category.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(Color(hex: poi.category.color))
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

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
        case "subtype": return String(localized: "poi.detail.subtype")
        case "municipality": return String(localized: "poi.detail.municipality")
        case "county": return String(localized: "poi.detail.county")
        default: return key
        }
    }
}
