import SwiftUI

struct MeasurementSheet: View {
    @Bindable var viewModel: MeasurementViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.mode == nil {
                    modeSelection
                } else {
                    activeMode
                }

                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "measurement.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        viewModel.stop()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Mode Selection

    private var modeSelection: some View {
        VStack(spacing: 16) {
            Text(String(localized: "measurement.selectMode"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
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
    }

    private func modeButton(mode: MeasurementMode, icon: String, label: String) -> some View {
        Button {
            viewModel.startMeasuring(mode: mode)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.Trakke.brand.opacity(0.1))
            .foregroundStyle(Color.Trakke.brand)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Active Mode

    private var activeMode: some View {
        VStack(spacing: 16) {
            // Mode indicator
            HStack {
                Image(systemName: viewModel.mode == .distance
                      ? "point.topleft.down.to.point.bottomright.curvepath"
                      : "skew")
                Text(viewModel.mode == .distance
                     ? String(localized: "measurement.distance")
                     : String(localized: "measurement.area"))
                    .font(.headline)
                Spacer()
            }

            // Instructions
            Text(viewModel.mode == .distance
                 ? String(localized: "measurement.distanceHint")
                 : String(localized: "measurement.areaHint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Stats
            HStack {
                Label(String(localized: "measurement.points \(viewModel.points.count)"), systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Result
            if let result = viewModel.formattedResult {
                HStack {
                    Text(viewModel.mode == .distance
                         ? String(localized: "measurement.distance")
                         : String(localized: "measurement.area"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(result)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(Color.Trakke.brand)
                }
                .padding()
                .background(Color.Trakke.brand.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Controls
            HStack(spacing: 12) {
                Button {
                    viewModel.undoLastPoint()
                } label: {
                    Label(String(localized: "route.undo"), systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.points.isEmpty)

                Button(role: .destructive) {
                    viewModel.clearAll()
                } label: {
                    Label(String(localized: "measurement.clear"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.points.isEmpty)
            }

            Button {
                viewModel.stop()
            } label: {
                Label(String(localized: "measurement.switchMode"), systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Trakke.brand)
            .disabled(!viewModel.points.isEmpty)
        }
    }
}
