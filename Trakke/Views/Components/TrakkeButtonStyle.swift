import SwiftUI

struct TrakkeButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, danger }
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, .Trakke.cardPadH)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: .white
        case .secondary: Color.Trakke.brand
        case .danger: Color.Trakke.red
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: Color.Trakke.brand
        case .secondary: Color(.secondarySystemGroupedBackground)
        case .danger: Color(.secondarySystemGroupedBackground)
        }
    }
}

extension ButtonStyle where Self == TrakkeButtonStyle {
    static var trakkePrimary: TrakkeButtonStyle { .init(variant: .primary) }
    static var trakkeSecondary: TrakkeButtonStyle { .init(variant: .secondary) }
    static var trakkeDanger: TrakkeButtonStyle { .init(variant: .danger) }
}
