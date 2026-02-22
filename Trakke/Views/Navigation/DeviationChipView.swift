import SwiftUI

struct DeviationChipView: View {
    let distance: Double
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Font.Trakke.bodyRegular)
                .accessibilityHidden(true)

            Text(String(localized: "navigation.offTrack \(Int(distance))"))
                .font(Font.Trakke.bodyRegular)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(Font.Trakke.caption.weight(.bold))
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.close"))
        }
        .foregroundStyle(Color.Trakke.text)
        .padding(.horizontal, .Trakke.lg)
        .padding(.vertical, .Trakke.sm)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .padding(.bottom, .Trakke.sm)
    }
}
