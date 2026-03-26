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
                            .accessibilityHidden(true)
                        Text(formattedDistance)
                            .font(Font.Trakke.numeralLarge)
                            .foregroundStyle(Color.Trakke.brand)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "accessibility.route.distance \(formattedDistance)"))
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
                            .padding(.vertical, .Trakke.sm)
                            .frame(minHeight: .Trakke.touchMin)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel(String(localized: "common.cancel"))

                    Button {
                        onUndo()
                    } label: {
                        Label(String(localized: "route.undo"), systemImage: "arrow.uturn.backward")
                            .padding(.horizontal, .Trakke.lg)
                            .padding(.vertical, .Trakke.sm)
                            .frame(minHeight: .Trakke.touchMin)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .disabled(pointCount == 0)
                    .accessibilityLabel(String(localized: "route.undo"))

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
                    .disabled(pointCount < 2)
                    .accessibilityLabel(String(localized: "common.done"))
                }
            }
            .padding(.bottom, .Trakke.lg)
        }
        .safeAreaPadding(.bottom)
    }
}
