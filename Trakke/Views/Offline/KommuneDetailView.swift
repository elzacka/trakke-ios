import SwiftUI

struct KommuneDetailView: View {
    let kommune: KommuneRegion
    @Bindable var viewModel: OfflineViewModel
    @Environment(\.dismiss) private var dismiss

    private let minZoom = 8
    private var maxZoom: Int { kommune.optimalMaxZoom(minZoom: minZoom) }
    private var tileCount: Int { kommune.estimatedTileCount(minZoom: minZoom, maxZoom: maxZoom) }
    private var isDownloaded: Bool { viewModel.isKommuneDownloaded(kommune) }

    var body: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                infoCard
                layerCard
                downloadSection

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(kommune.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Info

    private var infoCard: some View {
        CardSection(String(localized: "kommune.detail.info")) {
            VStack(spacing: 0) {
                infoRow(
                    label: String(localized: "kommune.detail.fylke"),
                    value: kommune.fylke
                )

                Divider()

                infoRow(
                    label: String(localized: "kommune.detail.area"),
                    value: kommune.areaDimensions
                )

                Divider()

                infoRow(
                    label: String(localized: "kommune.detail.zoomRange"),
                    value: OfflineMapService.zoomDescription(maxZoom: maxZoom)
                )

                Divider()

                infoRow(
                    label: String(localized: "kommune.detail.tiles"),
                    value: "\(tileCount)"
                )

                Divider()

                infoRow(
                    label: String(localized: "kommune.detail.size"),
                    value: OfflineMapService.formatBytes(OfflineMapService.estimateSize(tileCount: tileCount))
                )
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Font.Trakke.bodyRegular)
            Spacer()
            Text(value)
                .font(Font.Trakke.bodyRegular.monospacedDigit())
                .foregroundStyle(Color.Trakke.textSecondary)
        }
        .padding(.vertical, .Trakke.xs)
    }

    // MARK: - Layer

    private var layerCard: some View {
        CardSection(String(localized: "settings.baseLayer")) {
            Picker(String(localized: "settings.baseLayer"), selection: $viewModel.kommuneDownloadLayer) {
                ForEach(BaseLayer.allCases) { layer in
                    Text(layer.displayName).tag(layer)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Download

    @ViewBuilder
    private var downloadSection: some View {
        if isDownloaded {
            HStack(spacing: .Trakke.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.Trakke.brand)
                Text(String(localized: "kommune.detail.alreadyDownloaded"))
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .Trakke.buttonPadV)
        } else {
            Button {
                viewModel.startKommuneDownload(kommune)
                dismiss()
            } label: {
                Text(String(localized: "kommune.detail.download"))
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .Trakke.buttonPadV)
                    .background(Color.Trakke.brand)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            }
            .disabled(viewModel.isDownloading)
            .accessibilityLabel(String(localized: "kommune.detail.download"))
        }
    }
}
