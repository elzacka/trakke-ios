import SwiftUI

struct MeasurementToolbar: View {
    let mode: MeasurementMode
    let formattedResult: String?
    let hasPoints: Bool
    var onCancel: () -> Void
    var onUndo: () -> Void
    var onClear: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: .Trakke.sm) {
                if let result = formattedResult {
                    VStack(spacing: 2) {
                        Text(mode == .distance
                             ? String(localized: "measurement.distance")
                             : String(localized: "measurement.area"))
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.textTertiary)
                        Text(result)
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(Color.Trakke.brand)
                    }
                    .padding(.horizontal, .Trakke.lg)
                    .padding(.vertical, .Trakke.sm)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                } else {
                    Text(mode == .distance
                         ? String(localized: "measurement.distanceHint")
                         : String(localized: "measurement.areaHint"))
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
                    .disabled(!hasPoints)

                    Button {
                        onClear()
                    } label: {
                        Label(String(localized: "measurement.clear"), systemImage: "trash")
                            .padding(.horizontal, .Trakke.lg)
                            .padding(.vertical, 10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .disabled(!hasPoints)
                }
            }
            .padding(.bottom, .Trakke.lg)
        }
        .safeAreaPadding(.bottom)
    }
}
