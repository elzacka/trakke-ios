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
                        Text(String(localized: "offline.tiles \(estimatedTileCount)"))
                            .font(Font.Trakke.bodyRegular.monospacedDigit())
                        Text("(\(estimatedSize))")
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                    .foregroundStyle(estimatedTileCount > 20_000 ? Color.Trakke.red : .primary)
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
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }

                    Button {
                        onDone()
                    } label: {
                        Label(String(localized: "common.done"), systemImage: "checkmark")
                            .padding(.horizontal, .Trakke.lg)
                            .padding(.vertical, 10)
                            .background(Color.Trakke.brand)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(!hasValidSelection)
                }
            }
            .padding(.bottom, .Trakke.lg)
        }
        .safeAreaPadding(.bottom)
    }
}
