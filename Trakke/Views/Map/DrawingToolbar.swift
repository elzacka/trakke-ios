import SwiftUI

struct DrawingToolbar: View {
    let pointCount: Int
    let formattedDistance: String
    var onCancel: () -> Void
    var onUndo: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: .Trakke.sm) {
                if pointCount >= 2 {
                    HStack(spacing: .Trakke.rowVertical) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(Font.Trakke.caption)
                        Text(formattedDistance)
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(Color.Trakke.brand)
                    }
                    .padding(.horizontal, .Trakke.lg)
                    .padding(.vertical, .Trakke.sm)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                } else {
                    Text(String(localized: "route.drawingHint"))
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textTertiary)
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
                        onUndo()
                    } label: {
                        Label(String(localized: "route.undo"), systemImage: "arrow.uturn.backward")
                            .padding(.horizontal, .Trakke.lg)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .disabled(pointCount == 0)

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
                    .disabled(pointCount < 2)
                }
            }
            .padding(.bottom, .Trakke.lg)
        }
        .safeAreaPadding(.bottom)
    }
}
