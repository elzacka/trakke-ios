import SwiftUI

struct DownloadAreaSheet: View {
    @Bindable var viewModel: OfflineViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    selectionCard
                    configCard
                    estimateCard

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "offline.download"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        viewModel.cancelSelection()
                        dismiss()
                    }
                    .foregroundStyle(Color.Trakke.textTertiary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "offline.startDownload")) {
                        viewModel.startDownload()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canDownload)
                }
            }
        }
    }

    private var canDownload: Bool {
        viewModel.hasValidSelection
        && !viewModel.downloadName.isEmpty
        && viewModel.estimatedTileCount > 0
        && viewModel.estimatedTileCount <= 20_000
    }

    // MARK: - Selection

    private var selectionCard: some View {
        CardSection(String(localized: "offline.selectArea")) {
            HStack {
                if viewModel.hasValidSelection {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.Trakke.brand)
                    Text(String(localized: "offline.areaSelected"))
                        .font(Font.Trakke.bodyRegular)
                } else if viewModel.selectionCorner1 != nil {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(Color.Trakke.warning)
                    Text(String(localized: "offline.tapSecondCorner"))
                        .font(Font.Trakke.bodyRegular)
                } else {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(Color.Trakke.textTertiary)
                    Text(String(localized: "offline.tapFirstCorner"))
                        .font(Font.Trakke.bodyRegular)
                }
                Spacer()
            }

            Text(String(localized: "offline.selectAreaHint"))
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textTertiary)
                .padding(.top, .Trakke.xs)
        }
    }

    // MARK: - Configuration

    private var configCard: some View {
        CardSection(String(localized: "offline.configuration")) {
            VStack(spacing: 0) {
                TextField(String(localized: "offline.areaName"), text: $viewModel.downloadName)
                    .font(Font.Trakke.bodyRegular)
                    .padding(.vertical, .Trakke.rowVertical)

                Divider()

                HStack {
                    Text(String(localized: "settings.baseLayer"))
                        .font(Font.Trakke.bodyRegular)
                    Spacer()
                    Picker(String(localized: "settings.baseLayer"), selection: $viewModel.downloadLayer) {
                        ForEach(BaseLayer.allCases) { layer in
                            Text(layer.displayName).tag(layer)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .padding(.vertical, .Trakke.rowVertical)

                Divider()

                HStack {
                    Text(String(localized: "offline.zoomRange"))
                        .font(Font.Trakke.bodyRegular)
                    Spacer()
                    Stepper("\(viewModel.downloadMinZoom)", value: $viewModel.downloadMinZoom, in: 3...viewModel.downloadMaxZoom)
                        .fixedSize()
                }
                .padding(.vertical, .Trakke.xs)

                Divider()

                HStack {
                    Text(String(localized: "offline.zoomMax"))
                        .font(Font.Trakke.bodyRegular)
                    Spacer()
                    Stepper("\(viewModel.downloadMaxZoom)", value: $viewModel.downloadMaxZoom, in: viewModel.downloadMinZoom...18)
                        .fixedSize()
                }
                .padding(.vertical, .Trakke.xs)
            }
        }
    }

    // MARK: - Estimate

    private var estimateCard: some View {
        CardSection(String(localized: "offline.estimate")) {
            VStack(spacing: 0) {
                HStack {
                    Text(String(localized: "offline.tileCount"))
                        .font(Font.Trakke.bodyRegular)
                    Spacer()
                    Text("\(viewModel.estimatedTileCount)")
                        .font(Font.Trakke.bodyRegular.monospacedDigit())
                        .foregroundStyle(viewModel.estimatedTileCount > 20_000 ? Color.Trakke.red : .primary)
                }
                .padding(.vertical, .Trakke.xs)

                Divider()

                HStack {
                    Text(String(localized: "offline.estimatedSize"))
                        .font(Font.Trakke.bodyRegular)
                    Spacer()
                    Text(viewModel.estimatedSize)
                        .font(Font.Trakke.bodyRegular.monospacedDigit())
                }
                .padding(.vertical, .Trakke.xs)

                if viewModel.estimatedTileCount > 20_000 {
                    Divider()
                    Label(String(localized: "offline.tooManyTiles"), systemImage: "exclamationmark.triangle.fill")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.red)
                        .padding(.vertical, .Trakke.xs)
                } else if viewModel.estimatedTileCount > 1_000 {
                    Divider()
                    Label(String(localized: "offline.largeDownload"), systemImage: "info.circle")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.warning)
                        .padding(.vertical, .Trakke.xs)
                }
            }
        }
    }

}
