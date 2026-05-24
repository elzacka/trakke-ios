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
        .background(Color.Trakke.background)
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
    //
    // Radio-rad-mønster identisk med PreferencesSheet.baseLayerRow — én
    // TrakkeMenuRow per kartlag med checkmark-trailing for valgt. Samme
    // komponent og visuelle uttrykk så brukeren møter samme velger uansett
    // hvor i appen valget gjøres.

    private var layerCard: some View {
        CardSection(String(localized: "settings.baseLayer")) {
            VStack(spacing: 0) {
                ForEach(Array(BaseLayer.allCases.enumerated()), id: \.element) { index, layer in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    baseLayerRow(layer)
                }
            }
        }
    }

    private func baseLayerRow(_ layer: BaseLayer) -> some View {
        let isSelected = viewModel.kommuneDownloadLayer == layer

        return TrakkeMenuRow(
            label: layer.displayName,
            action: { viewModel.kommuneDownloadLayer = layer },
            trailing: { TrakkeMenuRowCheckmark(isSelected: isSelected) }
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
            // Bruker brandLight + hvit tekst — samme handlings-stil som
            // .trakkeSecondary, Avstand/Areal/Velg område osv.
            Button {
                viewModel.startKommuneDownload(kommune)
                dismiss()
            } label: {
                Text(String(localized: "kommune.detail.download"))
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .Trakke.buttonPadV)
                    .background(Color.Trakke.brandLight)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            }
            .disabled(viewModel.isDownloading)
            .accessibilityLabel(String(localized: "kommune.detail.download"))
        }
    }
}
