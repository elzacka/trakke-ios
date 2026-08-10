import SwiftUI

/// Custom topp for sheets – drag-handle (grabber) og valgfri brand-tittel.
/// Valgfri back-knapp vises på pushed views så designspråket holdes
/// konsistent også når NavigationStack pusher en ny visning.
///
/// Uten tittel står bare grabberen igjen. Menyens fem faner bruker den
/// varianten: hvilken fane du står på leser du allerede av bunnlinja, og
/// «Hjem» skrevet over et søkefelt du nettopp åpnet er en overskrift som
/// ikke forteller noe. Detaljark beholder tittelen, for der er navnet på
/// stedet, ruta eller artikkelen den eneste opplysningen om hva du ser på.
struct TrakkeSheetHeader: View {
    var title: String? = nil
    var onBack: (() -> Void)? = nil
    /// Skalerer med Dynamic Type – en fast 16 pt chevron ble stående
    /// uleselig liten ved store teksttørrelser.
    @ScaledMetric(relativeTo: .body) private var backIconSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, .Trakke.sm)
                // Uten tittel under trenger grabberen mindre luft: den skal
                // skille seg fra innholdet, ikke stå i en egen sone.
                .padding(.bottom, title == nil && onBack == nil ? .Trakke.md : .Trakke.lg)

            if title != nil || onBack != nil {
                HStack(alignment: .center, spacing: .Trakke.sm) {
                    if let onBack {
                        backButton(action: onBack)
                    }

                    if let title {
                        Text(title)
                            .font(Font.Trakke.articleTitle)
                            .foregroundStyle(Color.Trakke.brand)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }

                    Spacer()
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.bottom, .Trakke.lg)
            }
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.Trakke.borderStrong)
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: backIconSize, weight: .semibold))
                .foregroundStyle(Color.Trakke.brandLight)
                .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "common.back"))
    }
}

#Preview {
    VStack {
        TrakkeSheetHeader(title: "Naviger")
        TrakkeSheetHeader(title: "Friluftsliv", onBack: {})
        Spacer()
    }
    .background(Color.Trakke.background)
}
