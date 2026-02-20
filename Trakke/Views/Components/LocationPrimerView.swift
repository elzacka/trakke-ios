import SwiftUI

struct LocationPrimerView: View {
    let onAllow: () -> Void
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: .Trakke.lg) {
            Image(systemName: "location")
                .font(.title)
                .foregroundStyle(Color.Trakke.brand)

            VStack(spacing: .Trakke.sm) {
                Text(String(localized: "location.primer.title"))
                    .font(Font.Trakke.bodyMedium)

                Text(String(localized: "location.primer.body"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: .Trakke.sm) {
                Button {
                    onAllow()
                } label: {
                    Text(String(localized: "location.primer.allow"))
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.textInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .Trakke.md)
                        .background(Color.Trakke.brand)
                        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))
                }

                Button {
                    onDismiss()
                } label: {
                    Text(String(localized: "location.primer.notNow"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
                .frame(minHeight: .Trakke.touchMin)
            }
        }
        .padding(.Trakke.xl)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
        .trakkeCardShadow()
        .frame(maxWidth: 400)
        .padding(.horizontal, .Trakke.xxl)
    }
}
