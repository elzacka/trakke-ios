import SwiftUI

/// Custom topp for sheets – drag-handle (grabber) og stor brand-tittel.
/// Valgfri back-knapp vises på pushed views så designspråket holdes
/// konsistent også når NavigationStack pusher en ny visning.
struct TrakkeSheetHeader: View {
    let title: String
    var onBack: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, .Trakke.sm)
                .padding(.bottom, .Trakke.lg)

            HStack(alignment: .center, spacing: .Trakke.sm) {
                if let onBack {
                    backButton(action: onBack)
                }

                Text(title)
                    .font(Font.Trakke.articleTitle)
                    .foregroundStyle(Color.Trakke.brand)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer()
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.bottom, .Trakke.lg)
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
                .font(.system(size: 16, weight: .semibold))
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
