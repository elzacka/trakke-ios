import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        // Ingen ikon. Nålen, huset og sirkelen skilte sted, adresse og
        // koordinat, men navnet og underteksten sier allerede hvilken av
        // delene et treff er. Å beholde ikonet bare for stedstreff ville
        // dessuten gitt en rufsete venstrekant der noen rader er innrykket
        // og andre ikke.
        HStack(spacing: .Trakke.md) {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(result.displayName)
                    .font(Font.Trakke.bodyMedium)
                    .lineLimit(1)

                if let subtext = result.subtext {
                    Text(subtext)
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = result.displayName
        if let subtext = result.subtext {
            text += ", \(subtext)"
        }
        return text
    }
}
