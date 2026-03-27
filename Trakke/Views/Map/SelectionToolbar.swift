import SwiftUI

struct SelectionToolbar: View {
    let hasValidSelection: Bool
    let estimatedTileCount: Int
    let estimatedSize: String
    var onCancel: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: .Trakke.sm) {
                if hasValidSelection {
                    HStack(spacing: .Trakke.rowVertical) {
                        Image(systemName: "square.grid.3x3")
                            .font(Font.Trakke.caption)
                            .accessibilityHidden(true)
                        Text(String(localized: "offline.tiles \(estimatedTileCount)"))
                            .font(Font.Trakke.bodyRegular.monospacedDigit())
                        Text("(\(estimatedSize))")
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .foregroundStyle(estimatedTileCount > 20_000 ? Color.Trakke.red : .primary)
                    .accessibilityLabel(estimatedTileCount > 20_000
                        ? String(localized: "offline.tooManyTiles")
                        : String(localized: "offline.tiles \(estimatedTileCount)")
                    )
                    .padding(.horizontal, .Trakke.lg)
                    .padding(.vertical, .Trakke.sm)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                }

                HStack(spacing: .Trakke.lg) {
                    Button(role: .destructive) {
                        onCancel()
                    } label: {
                        Label(String(localized: "common.cancel"), systemImage: "xmark")
                            .foregroundStyle(Color.Trakke.red)
                            .padding(.horizontal, .Trakke.lg)
                            .padding(.vertical, .Trakke.sm)
                            .frame(minHeight: .Trakke.touchMin)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel(String(localized: "common.cancel"))

                    Button {
                        onDone()
                    } label: {
                        Label(String(localized: "common.done"), systemImage: "checkmark")
                            .padding(.horizontal, .Trakke.lg)
                            .padding(.vertical, .Trakke.sm)
                            .frame(minHeight: .Trakke.touchMin)
                            .background(Color.Trakke.brand)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(!hasValidSelection)
                    .accessibilityLabel(String(localized: "common.done"))
                }
            }
            .padding(.bottom, .Trakke.lg)
        }
        .safeAreaPadding(.bottom)
    }
}
