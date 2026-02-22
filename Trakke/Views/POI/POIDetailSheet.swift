import SwiftUI
import CoreLocation

struct POIDetailSheet: View {
    let poi: POI
    var onNavigate: ((CLLocationCoordinate2D) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                    // MARK: - Category
                    Text(poi.category.displayName)
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textTertiary)

                    // MARK: - Details
                    if !poi.details.isEmpty {
                        CardSection(String(localized: "poi.details")) {
                            ForEach(Array(sortedDetails.enumerated()), id: \.element.key) { index, detail in
                                if index > 0 {
                                    Divider().padding(.leading, .Trakke.dividerLeading)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizedDetailKey(detail.key))
                                        .font(Font.Trakke.caption)
                                        .foregroundStyle(Color.Trakke.textTertiary)
                                    Text(localizedDetailValue(key: detail.key, value: detail.value))
                                        .font(Font.Trakke.bodyRegular)
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
                                .font(Font.Trakke.bodyRegular.monospacedDigit())
                            Spacer()
                            Button {
                                UIPasteboard.general.string = formatted.copyText
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(Font.Trakke.bodyRegular)
                                    .foregroundStyle(Color.Trakke.brand)
                                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                                    .contentShape(Rectangle())
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
                                        .font(Font.Trakke.bodyRegular)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(Font.Trakke.captionSoft)
                                        .foregroundStyle(Color.Trakke.textTertiary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // MARK: - Navigate
                    Button {
                        onNavigate?(poi.coordinate)
                    } label: {
                        Label(String(localized: "navigation.navigateHere"), systemImage: "location.north.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkePrimary)

                    // MARK: - Data Source Attribution
                    HStack(spacing: .Trakke.xs) {
                        Text(String(localized: "poi.source"))
                        Text(poi.category.sourceName)
                        Text("(\(poi.category.sourceLicense))")
                    }
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .Trakke.xs)

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
        case "elevation": return String(localized: "poi.detail.elevation")
        case "direction": return String(localized: "poi.detail.direction")
        case "type": return String(localized: "poi.detail.type")
        case "municipality": return String(localized: "poi.detail.municipality")
        case "county": return String(localized: "poi.detail.county")
        default: return key
        }
    }

    private func localizedDetailValue(key: String, value: String) -> String {
        guard key == "type" || key == "subtype" else { return value }
        switch value {
        case "observation_tower": return "Utsiktstårn"
        case "bird_hide": return "Fugletårn"
        case "watchtower": return "Vakttårn"
        case "bunker": return "Bunker"
        case "fort": return "Festning"
        case "battlefield": return "Slagmark"
        default: return value
        }
    }
}
