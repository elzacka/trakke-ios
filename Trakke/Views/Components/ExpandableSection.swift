import SwiftUI

/// Akkordeon-seksjon i CardSection-stil. Brukes til å samle tunge
/// underflater (Innstillinger, Kunnskap, Informasjon) i samme visning
/// uten å åpne en ny push-skjerm.
///
/// Innholdet konstrueres bare når seksjonen er ekspandert – kollapset
/// tilstand tar minimalt med plass og kjører ingen onAppear-effekter
/// for innholdet under.
struct ExpandableSection<Content: View>: View {
    let title: String
    var initiallyExpanded: Bool = false
    /// Bare-modus: dropp den ytre CardSection-innpakningen – brukes når
    /// flere akkordeoner skal dele samme kort under en felles tittel.
    var bare: Bool = false
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ title: String,
        initiallyExpanded: Bool = false,
        bare: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.initiallyExpanded = initiallyExpanded
        self.bare = bare
        self.content = content
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        if bare {
            sectionBody
        } else {
            CardSection { sectionBody }
        }
    }

    private var sectionBody: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: .Trakke.md) {
                    Text(title)
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(Font.Trakke.captionSoft.weight(.semibold))
                        .foregroundStyle(Color.Trakke.textSoft)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 12)
                .frame(minHeight: .Trakke.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(isExpanded
                ? String(localized: "accessibility.tapToCollapse")
                : String(localized: "accessibility.tapToExpand"))

            if isExpanded {
                Divider().padding(.leading, .Trakke.dividerLeading)
                content()
                    .padding(.top, .Trakke.sm)
            }
        }
    }
}
