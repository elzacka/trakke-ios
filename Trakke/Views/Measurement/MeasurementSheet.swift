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
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        label: String(localized: "measurement.distance")
                    )

                    modeButton(
                        mode: .area,
                        icon: "skew",
                        label: String(localized: "measurement.area")
                    )
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
            .padding(.bottom, .Trakke.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "measurement.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Mode Button

    private func modeButton(mode: MeasurementMode, icon: String, label: String) -> some View {
        Button {
            viewModel.startMeasuring(mode: mode)
            dismiss()
        } label: {
            VStack(spacing: .Trakke.rowVertical) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(Font.Trakke.bodyRegular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.Trakke.brand.opacity(0.1))
            .foregroundStyle(Color.Trakke.brand)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        }
    }
}
