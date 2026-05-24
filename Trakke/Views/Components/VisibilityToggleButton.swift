import SwiftUI

/// Standardisert hake-knapp for å toggle synlighet på kartet fra list-rader.
/// Brukes på rader i WaypointListSheet, RouteListSheet, ActivityListSheet
/// for å gi 1-tap synlighet-toggle uten å åpne detail-sheet.
///
/// Visuelt mønster — samme som POI-underkategorier:
/// - synlig: hake (brandLight-grønn)
/// - skjult: ingen hake (tom)
///
/// Tap toggler tilstand. 44pt touch target er alltid bevart, også når
/// haken er skjult, så raden kan toggles tilbake til synlig.
struct VisibilityToggleButton: View {
    let isVisible: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isVisible {
                    Image(systemName: "checkmark")
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.brandLight)
                } else {
                    // Tom plassholder — bevarer 44pt tap-areal når haken er skjult.
                    Color.clear
                }
            }
            .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isVisible ? .isSelected : [])
    }
}
