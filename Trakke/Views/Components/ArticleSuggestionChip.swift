import SwiftUI

/// A subtle, dismissable chip that suggests a knowledge article.
struct ArticleSuggestionChip: View {
    let text: String
    var onTap: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "book.closed")
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.brandLight)
                .accessibilityHidden(true)

            Text(text)
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.brand)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(Font.Trakke.captionSoft.weight(.bold))
                    .foregroundStyle(Color.Trakke.brandLight)
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.close"))
        }
        .padding(.leading, .Trakke.md)
        .padding(.vertical, .Trakke.xs)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, .Trakke.sheetHorizontal)
        .padding(.bottom, .Trakke.xs)
        .onTapGesture { onTap() }
        // Chipen er primært en knapp som åpner artikkelen; lukk er en
        // sekundær rotor-handling. Uten dette leste VoiceOver bare lukk-knappen.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityAction(named: String(localized: "common.close")) { onDismiss() }
    }
}
