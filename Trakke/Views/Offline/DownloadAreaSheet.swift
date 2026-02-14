import SwiftUI

struct DownloadAreaSheet: View {
    @Bindable var viewModel: OfflineViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                selectionSection
                configSection
                estimateSection
            }
            .navigationTitle(String(localized: "offline.download"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        viewModel.cancelSelection()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "offline.startDownload")) {
                        viewModel.startDownload()
                        dismiss()
                    }
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

    // MARK: - Sections

    private var selectionSection: some View {
        Section {
            if viewModel.hasValidSelection {
                Label(String(localized: "offline.areaSelected"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if viewModel.selectionCorner1 != nil {
                Label(String(localized: "offline.tapSecondCorner"), systemImage: "hand.tap")
                    .foregroundStyle(.orange)
            } else {
                Label(String(localized: "offline.tapFirstCorner"), systemImage: "hand.tap")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "offline.selectArea"))
        } footer: {
            Text(String(localized: "offline.selectAreaHint"))
        }
    }

    private var configSection: some View {
        Section(String(localized: "offline.configuration")) {
            TextField(String(localized: "offline.areaName"), text: $viewModel.downloadName)

            Picker(String(localized: "settings.baseLayer"), selection: $viewModel.downloadLayer) {
                ForEach(BaseLayer.allCases) { layer in
                    Text(layer.displayName).tag(layer)
                }
            }

            HStack {
                Text(String(localized: "offline.zoomRange"))
                Spacer()
                Stepper("\(viewModel.downloadMinZoom)", value: $viewModel.downloadMinZoom, in: 3...viewModel.downloadMaxZoom)
                    .fixedSize()
            }

            HStack {
                Text(String(localized: "offline.zoomMax"))
                Spacer()
                Stepper("\(viewModel.downloadMaxZoom)", value: $viewModel.downloadMaxZoom, in: viewModel.downloadMinZoom...18)
                    .fixedSize()
            }
        }
    }

    private var estimateSection: some View {
        Section(String(localized: "offline.estimate")) {
            HStack {
                Text(String(localized: "offline.tileCount"))
                Spacer()
                Text("\(viewModel.estimatedTileCount)")
                    .monospacedDigit()
                    .foregroundStyle(viewModel.estimatedTileCount > 20_000 ? .red : .primary)
            }

            HStack {
                Text(String(localized: "offline.estimatedSize"))
                Spacer()
                Text(viewModel.estimatedSize)
                    .monospacedDigit()
            }

            if viewModel.estimatedTileCount > 20_000 {
                Label(String(localized: "offline.tooManyTiles"), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if viewModel.estimatedTileCount > 1_000 {
                Label(String(localized: "offline.largDownload"), systemImage: "info.circle")
                    .foregroundStyle(.orange)
            }
        }
    }
}
