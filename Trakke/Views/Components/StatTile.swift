import SwiftUI

/// Stor stat-tile med tall over en kort label.
/// Brukes i navigasjons-HUD, vær-sheet og andre flater der brukeren skanner
/// nøkkeltall på avstand. Inspirert av AllTrails sin stats-grid.
struct StatTile: View {
    let value: String
    let label: String
    var valueColor: Color = Color.Trakke.brand
    var numericTransition: Bool = true

    var body: some View {
        VStack(spacing: .Trakke.labelGap) {
            Text(value)
                .font(Font.Trakke.numeralXLarge)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(numericTransition ? .numericText() : .identity)

            Text(label)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
        StatTile(value: "48:30", label: "Tid")
        StatTile(value: "1,5 km", label: "Distanse")
        StatTile(value: "201 m", label: "Stigning")
        StatTile(value: "32:20", label: "Tempo")
        StatTile(value: "5,2 km", label: "Gjenstår")
        StatTile(value: "1,86", label: "Hastighet")
    }
    .padding()
}
