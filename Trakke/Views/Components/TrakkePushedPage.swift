import SwiftUI

/// Standard ramme for visninger som pushes i en NavigationStack: skjuler
/// systemets navigasjonslinje og tegner TrakkeSheetHeader med appens egen
/// tilbakeknapp, slik kunnskapsartiklene gjør. Alle pushede visninger skal
/// bruke denne, så tilbakeknappen ser lik ut i hele appen – systemets
/// tilbakeknapp og vår chevron skal aldri opptre om hverandre.
struct TrakkePushedPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TrakkeSheetHeader(title: title, onBack: { dismiss() })
            content()
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .toolbar(.hidden, for: .navigationBar)
    }
}
