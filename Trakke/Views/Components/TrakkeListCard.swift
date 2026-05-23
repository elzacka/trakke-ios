import SwiftUI

/// Flat hvit kort for liste-elementer. Erstatter iOS-default `List`-rader
/// med PWA-stil flate kort på off-white bakgrunn.
struct TrakkeListCard<Content: View>: View {
    var horizontalPadding: CGFloat = .Trakke.cardPadH
    var verticalPadding: CGFloat = 14
    var cornerRadius: CGFloat = .TrakkeRadius.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color.Trakke.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack(spacing: .Trakke.sm) {
        TrakkeListCard {
            HStack {
                Image(systemName: "map")
                    .foregroundStyle(Color.Trakke.brand)
                VStack(alignment: .leading) {
                    Text("Sognsvann rundt").font(Font.Trakke.bodyMedium)
                    Text("4,2 km · Lett").font(Font.Trakke.captionSoft).foregroundStyle(Color.Trakke.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.Trakke.textTertiary)
            }
        }
        TrakkeListCard {
            Text("Maridalen lengdetur").font(Font.Trakke.bodyMedium)
        }
    }
    .padding()
    .background(Color.Trakke.background)
}
