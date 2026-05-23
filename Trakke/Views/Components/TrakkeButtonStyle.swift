import SwiftUI

struct TrakkeButtonStyle: ButtonStyle {
    /// Knappehierarki:
    /// - `primary`: Hovedhandling i flyten (start, fortsett, naviger). Maks én per skjerm.
    /// - `secondary`: Sidestilt handling (eksporter, dupliser).
    /// - `tertiary`: Lavprofil-handling. Som secondary, men uten bakgrunn — for
    ///   handlinger som ikke trenger visuell vekt (avbryt, hjelp, lenker).
    /// - `danger`: Destruktiv handling (slett). Maks én per skjerm, sist i listen.
    enum Variant { case primary, secondary, tertiary, danger }
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        TrakkeButtonBody(configuration: configuration, variant: variant)
    }

    fileprivate static func foregroundColor(for variant: Variant) -> Color {
        switch variant {
        case .primary: .white
        case .secondary, .tertiary: Color.Trakke.brand
        case .danger: Color.Trakke.red
        }
    }

    fileprivate static func backgroundColor(for variant: Variant) -> Color {
        switch variant {
        case .primary: Color.Trakke.brand
        case .secondary: Color.Trakke.surface
        case .tertiary: Color.clear
        case .danger: Color.Trakke.surface
        }
    }
}

private struct TrakkeButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: TrakkeButtonStyle.Variant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(Font.Trakke.bodyMedium)
            .foregroundStyle(TrakkeButtonStyle.foregroundColor(for: variant))
            .frame(maxWidth: .infinity)
            .padding(.vertical, .Trakke.buttonPadV)
            .padding(.horizontal, .Trakke.cardPadH)
            .background(TrakkeButtonStyle.backgroundColor(for: variant))
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            .frame(maxWidth: 400)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TrakkeButtonStyle {
    static var trakkePrimary: TrakkeButtonStyle { .init(variant: .primary) }
    static var trakkeSecondary: TrakkeButtonStyle { .init(variant: .secondary) }
    static var trakkeTertiary: TrakkeButtonStyle { .init(variant: .tertiary) }
    static var trakkeDanger: TrakkeButtonStyle { .init(variant: .danger) }
}
