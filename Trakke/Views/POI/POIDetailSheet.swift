import SwiftUI
import CoreLocation

/// Detalj-sheet for et POI på kartet – bruker samme designspråk som resten
/// av appen: TrakkeSheetHeader øverst, off-white bakgrunn, flate CardSection-
/// kort, brand-tekst og PWA-trofaste farger.
struct POIDetailSheet: View {
    let poi: POI
    var onNavigate: ((CLLocationCoordinate2D) -> Void)?
    @State private var copied = false
    @AppStorage(AppStorageKeys.coordinateFormat) private var coordinateFormat: CoordinateFormat = .dd

    var body: some View {
        VStack(spacing: 0) {
            TrakkeSheetHeader(title: poi.name)

            ScrollView {
                VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                    // MARK: - Felter (alle bruker innebygget overskrift)
                    CardSection {
                        if !poi.details.isEmpty {
                            ForEach(Array(sortedDetails.enumerated()), id: \.element.key) { index, detail in
                                if index > 0 {
                                    Divider().padding(.leading, .Trakke.dividerLeading)
                                }
                                fieldRow(
                                    label: localizedDetailKey(detail.key),
                                    value: localizedDetailValue(key: detail.key, value: detail.value)
                                )
                            }
                            Divider().padding(.leading, .Trakke.dividerLeading)
                        }

                        coordinatesFieldRow

                        if let link = poi.details["link"],
                           let url = URL(string: link),
                           url.scheme == "https" {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                            externalLinkFieldRow(url: url)
                        }
                    }

                    // MARK: - Navigate
                    // Ikon-knapp høyrejustert – samme stil som detail-arkene
                    // for ruter, turer og steder.
                    HStack(spacing: .Trakke.sm) {
                        Spacer()
                        TrakkeIconButton(
                            systemImage: "location.north.fill",
                            accessibilityLabel: String(localized: "navigation.navigateHere"),
                            action: { onNavigate?(poi.coordinate) }
                        )
                    }

                    // MARK: - Data Source Attribution
                    HStack(spacing: .Trakke.xs) {
                        Text(String(localized: "poi.source"))
                        Text(poi.category.sourceName)
                    }
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .Trakke.xs)

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sm)
                .padding(.bottom, .Trakke.xxl)
            }
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
    }

    // MARK: - Felt-rader (innebygget overskrift)

    /// Standard tekst-rad: liten label på topp, verdi under.
    private func fieldRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
            Text(label)
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textSoft)
            Text(value)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .Trakke.rowVertical)
    }

    /// Koordinat-rad: label "Koordinater" øverst + monospace-verdi med kopier-knapp.
    private var coordinatesFieldRow: some View {
        let formatted = CoordinateService.format(coordinate: poi.coordinate, format: coordinateFormat)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(String(localized: "poi.coordinates"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                Text(formatted.display)
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                    .foregroundStyle(Color.Trakke.text)
            }
            Spacer()
            Button {
                UIPasteboard.general.setItems(
                    [["public.utf8-plain-text": formatted.copyText]],
                    options: [.expirationDate: Date().addingTimeInterval(300)]
                )
                copied = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.brandLight)
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.copy"))
        }
        .padding(.vertical, .Trakke.rowVertical)
    }

    /// Ekstern-lenke-rad: label "Lenke" øverst + tappable Link med arrow-glyph.
    private func externalLinkFieldRow(url: URL) -> some View {
        Link(destination: url) {
            HStack {
                VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                    Text(String(localized: "poi.moreInfo"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                    Text(url.host ?? url.absoluteString)
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.textSoft)
            }
            .padding(.vertical, .Trakke.rowVertical)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "poi.moreInfo"))
    }

    // MARK: - Helpers

    /// Tekniske/interne feltnavn vi ikke vil vise i detalj-arket. `link` og
    /// `source` håndteres separat (link rendres som egen seksjon, source
    /// vises som attribusjon i bunnen). `osm_ref` og `wikidata_id` er
    /// kildedatabase-ID-er uten brukerverdi.
    private static let hiddenDetailKeys: Set<String> = [
        "link", "source", "osm_ref", "wikidata_id",
    ]

    /// Felter som skal vises først i detalj-arket, i denne rekkefølgen.
    /// Resten sorteres alfabetisk under. Provider/subtype/type/shelterType
    /// beskriver *hva* dette er – viktigere enn beskrivelse, høyde osv.
    /// Owner/operator kommer rett etter siden «hvem driver dette» har høy
    /// nytteverdi for hytter og lignende.
    private static let priorityDetailKeys: [String] = [
        "provider", "subtype", "type", "shelterType", "owner", "operator",
    ]

    private var sortedDetails: [(key: String, value: String)] {
        let visible = poi.details.filter { !Self.hiddenDetailKeys.contains($0.key) }
        let prioritized = Self.priorityDetailKeys.compactMap { key -> (key: String, value: String)? in
            guard let value = visible[key] else { return nil }
            return (key: key, value: value)
        }
        let rest = visible
            .filter { !Self.priorityDetailKeys.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key, value: $0.value) }
        return prioritized + rest
    }

    private func localizedDetailKey(_ key: String) -> String {
        switch key {
        case "address": return String(localized: "poi.detail.address")
        case "beds": return String(localized: "poi.detail.beds")
        case "capacity": return String(localized: "poi.detail.capacity")
        case "category": return String(localized: "poi.detail.category")
        case "description": return String(localized: "poi.detail.description")
        case "height": return String(localized: "poi.detail.height")
        case "operator": return String(localized: "poi.detail.operator")
        case "owner": return String(localized: "poi.detail.owner")
        case "inscription": return String(localized: "poi.detail.inscription")
        case "period": return String(localized: "poi.detail.period")
        case "provider": return String(localized: "poi.detail.provider")
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
        if key == "provider" {
            switch value {
            case "dnt": return "DNT"
            case "andre": return "Andre"
            default: return value
            }
        }
        guard key == "type" || key == "subtype" || key == "shelterType" else { return value }
        switch value {
        // Badeplass-undertyper (konsolidert kategori)
        case "badeplass": return "Badeplass"
        case "jettegryte": return "Jettegryte"
        case "kroksjo": return "Kroksjø"
        case "lagune": return "Lagune"
        case "varme_kilder": return "Varm kilde"
        // Viewpoints
        case "observation_tower": return "Utsiktstårn"
        case "bird_hide": return "Fugletårn"
        case "watchtower": return "Vakttårn"
        // War memorials
        case "bunker": return "Bunker"
        case "fort": return "Festning"
        case "battlefield": return "Slagmark"
        // Wilderness shelters
        case "lean_to": return "Gapahuk"
        case "basic_hut": return "Enkel hytte"
        case "picnic_shelter": return "Rasteplass med tak"
        case "weather_shelter": return "Vindskjul"
        case "rock_shelter": return "Heller"
        case "gazebo": return "Lysthus"
        case "pavilion": return "Paviljong"
        case "lavvu": return "Lavvo"
        case "wildlife_hide": return "Fugleskjul"
        case "field_shelter": return "Felthytte"
        case "wilderness_hut": return "Fjellhytte"
        case "tent": return "Teltplass"
        case "turf_hut": return "Torvhytte"
        case "public_transport": return "Leskur"
        default: return value
        }
    }
}
