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
                    .foregroundStyle(Color.Trakke.textSoft)
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
                        .font(.subheadline)
                } else if viewModel.selectionCorner1 != nil {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(.orange)
                    Text(String(localized: "offline.tapSecondCorner"))
                        .font(.subheadline)
                } else {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(Color.Trakke.textSoft)
                    Text(String(localized: "offline.tapFirstCorner"))
                        .font(.subheadline)
                }
                Spacer()
            }

            Text(String(localized: "offline.selectAreaHint"))
                .font(.caption)
                .foregroundStyle(Color.Trakke.textSoft)
                .padding(.top, 4)
        }
    }

    // MARK: - Configuration

    private var configCard: some View {
        CardSection(String(localized: "offline.configuration")) {
            VStack(spacing: 0) {
                TextField(String(localized: "offline.areaName"), text: $viewModel.downloadName)
                    .font(.subheadline)
                    .padding(.vertical, 6)

                Divider()

                HStack {
                    Text(String(localized: "settings.baseLayer"))
                        .font(.subheadline)
                    Spacer()
                    Picker(String(localized: "settings.baseLayer"), selection: $viewModel.downloadLayer) {
                        ForEach(BaseLayer.allCases) { layer in
                            Text(layer.displayName).tag(layer)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 6)

                Divider()

                HStack {
                    Text(String(localized: "offline.zoomRange"))
                        .font(.subheadline)
                    Spacer()
                    Stepper("\(viewModel.downloadMinZoom)", value: $viewModel.downloadMinZoom, in: 3...viewModel.downloadMaxZoom)
                        .fixedSize()
                }
                .padding(.vertical, 4)

                Divider()

                HStack {
                    Text(String(localized: "offline.zoomMax"))
                        .font(.subheadline)
                    Spacer()
                    Stepper("\(viewModel.downloadMaxZoom)", value: $viewModel.downloadMaxZoom, in: viewModel.downloadMinZoom...18)
                        .fixedSize()
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Estimate

    private var estimateCard: some View {
        CardSection(String(localized: "offline.estimate")) {
            VStack(spacing: 0) {
                HStack {
                    Text(String(localized: "offline.tileCount"))
                        .font(.subheadline)
                    Spacer()
                    Text("\(viewModel.estimatedTileCount)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(viewModel.estimatedTileCount > 20_000 ? Color.Trakke.red : .primary)
                }
                .padding(.vertical, 4)

                Divider()

                HStack {
                    Text(String(localized: "offline.estimatedSize"))
                        .font(.subheadline)
                    Spacer()
                    Text(viewModel.estimatedSize)
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.vertical, 4)

                if viewModel.estimatedTileCount > 20_000 {
                    Divider()
                    Label(String(localized: "offline.tooManyTiles"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.red)
                        .padding(.vertical, 4)
                } else if viewModel.estimatedTileCount > 1_000 {
                    Divider()
                    Label(String(localized: "offline.largeDownload"), systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.vertical, 4)
                }
            }
        }
    }

}
