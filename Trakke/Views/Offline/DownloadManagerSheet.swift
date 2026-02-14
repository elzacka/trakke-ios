import SwiftUI

struct DownloadManagerSheet: View {
    @Bindable var viewModel: OfflineViewModel
    var onNewDownload: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.packs.isEmpty {
                    ContentUnavailableView(
                        String(localized: "offline.empty"),
                        systemImage: "arrow.down.circle",
                        description: Text(String(localized: "offline.emptyDescription"))
                    )
                } else {
                    packList
                }
            }
            .navigationTitle(String(localized: "offline.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNewDownload?()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "offline.download"))
                }
            }
        }
    }

    private var packList: some View {
        List {
            ForEach(viewModel.packs) { pack in
                packRow(pack)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deletePack(viewModel.packs[index])
                }
            }

            Section {
                storageInfo
            }
        }
    }

    private func packRow(_ pack: OfflinePackInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pack.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text(layerDisplayName(pack.layer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Z\(pack.minZoom)-\(pack.maxZoom)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(OfflineMapService.formatBytes(Int64(pack.progress.completedBytes)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !pack.progress.isComplete {
                ProgressView(value: pack.progress.percentage, total: 100)
                    .tint(Color.Trakke.brand)

                Text(String(format: "%.0f%%", pack.progress.percentage))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(String(localized: "offline.complete"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var storageInfo: some View {
        HStack {
            Text(String(localized: "offline.totalStorage"))
                .foregroundStyle(.secondary)
            Spacer()
            let totalBytes = viewModel.packs.reduce(Int64(0)) { $0 + Int64($1.progress.completedBytes) }
            Text(OfflineMapService.formatBytes(totalBytes))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func layerDisplayName(_ layer: String) -> String {
        switch layer {
        case "topo": return String(localized: "map.layer.topo")
        case "grayscale": return String(localized: "map.layer.grayscale")
        default: return layer
        }
    }
}
