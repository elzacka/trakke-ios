import SwiftUI

struct TrakkeButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, danger }
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        TrakkeButtonBody(configuration: configuration, variant: variant)
    }

    fileprivate static func foregroundColor(for variant: Variant) -> Color {
        switch variant {
        case .primary: .white
        case .secondary: Color.Trakke.brand
        case .danger: Color.Trakke.red
        }
    }

    fileprivate static func backgroundColor(for variant: Variant) -> Color {
        switch variant {
        case .primary: Color.Trakke.brand
        case .secondary: Color(.secondarySystemGroupedBackground)
        case .danger: Color(.secondarySystemGroupedBackground)
        }
    }
}

private struct TrakkeButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: TrakkeButtonStyle.Variant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(TrakkeButtonStyle.foregroundColor(for: variant))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, .Trakke.cardPadH)
            .background(TrakkeButtonStyle.backgroundColor(for: variant))
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TrakkeButtonStyle {
    static var trakkePrimary: TrakkeButtonStyle { .init(variant: .primary) }
    static var trakkeSecondary: TrakkeButtonStyle { .init(variant: .secondary) }
    static var trakkeDanger: TrakkeButtonStyle { .init(variant: .danger) }
}
