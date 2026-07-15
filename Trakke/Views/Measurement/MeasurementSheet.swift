import SwiftUI

struct MeasurementSheet: View {
    @Bindable var viewModel: MeasurementViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: .Trakke.md) {
                Text(String(localized: "measurement.selectMode"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: .Trakke.md) {
                    modeButton(
                        mode: .distance,
                        label: String(localized: "measurement.distance")
                    )

                    modeButton(
                        mode: .area,
                        label: String(localized: "measurement.area")
                    )
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
            .padding(.bottom, .Trakke.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.Trakke.background)
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "measurement.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Mode Button

    private func modeButton(mode: MeasurementMode, label: String) -> some View {
        Button {
            viewModel.startMeasuring(mode: mode)
            dismiss()
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.trakkeSecondary)
    }
}
