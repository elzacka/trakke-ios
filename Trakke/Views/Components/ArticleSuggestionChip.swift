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
                .accessibilityHidden(true)

            Text(text)
                .font(Font.Trakke.caption)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(Font.Trakke.captionSoft.weight(.bold))
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.close"))
        }
        .foregroundStyle(Color.Trakke.brand)
        .padding(.leading, .Trakke.md)
        .padding(.vertical, .Trakke.xs)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, .Trakke.sheetHorizontal)
        .padding(.bottom, .Trakke.xs)
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
