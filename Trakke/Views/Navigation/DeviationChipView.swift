import SwiftUI

struct DeviationChipView: View {
    let distance: Double
    var canReroute: Bool = false
    var onReroute: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Font.Trakke.bodyRegular)
                .accessibilityHidden(true)

            Text(String(localized: "navigation.offTrack \(Int(distance))"))
                .font(Font.Trakke.bodyRegular)
                .accessibilityAddTraits(.isStaticText)

            if canReroute, let onReroute {
                Button {
                    onReroute()
                } label: {
                    Text(String(localized: "navigation.reroute"))
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.brand)
                        .padding(.horizontal, .Trakke.xs)
                        .frame(minHeight: .Trakke.touchMin)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "navigation.reroute"))
            }

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
        .accessibilityElement(children: .contain)
    }
}
