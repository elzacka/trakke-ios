import SwiftUI

struct DownloadManagerSheet: View {
    @Bindable var viewModel: OfflineViewModel
    var onNewDownload: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var packToDelete: OfflinePackInfo?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.packs.isEmpty {
                    EmptyStateView(
                        icon: "arrow.down.circle",
                        title: String(localized: "offline.empty.title"),
                        subtitle: String(localized: "offline.empty.subtitle")
                    )
                } else {
                    packList
                }
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "offline.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onNewDownload?()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "offline.download"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .alert(
                String(localized: "offline.deleteConfirm.title"),
                isPresented: Binding(
                    get: { packToDelete != nil },
                    set: { if !$0 { packToDelete = nil } }
                )
            ) {
                Button(String(localized: "common.delete"), role: .destructive) {
                    if let pack = packToDelete {
                        viewModel.deletePack(pack)
                    }
                    packToDelete = nil
                }
                Button(String(localized: "common.cancel"), role: .cancel) {
                    packToDelete = nil
                }
            } message: {
                if let pack = packToDelete {
                    Text(String(localized: "offline.deleteConfirm.message \(pack.name)"))
                }
            }
        }
    }

    private var packList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                // Info about how offline maps work
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                    Text(String(localized: "offline.autoUseHint"))
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

                CardSection(String(localized: "offline.packs")) {
                    ForEach(Array(viewModel.packs.enumerated()), id: \.element.id) { index, pack in
                        if index > 0 {
                            Divider().padding(.leading, 4)
                        }
                        packRow(pack)
                    }
                }

                // Storage info
                HStack {
                    Text(String(localized: "offline.totalStorage"))
                        .foregroundStyle(Color.Trakke.textSoft)
                    Spacer()
                    let totalBytes = viewModel.packs.reduce(Int64(0)) { $0 + Int64($1.progress.completedBytes) }
                    Text(OfflineMapService.formatBytes(totalBytes))
                        .monospacedDigit()
                        .foregroundStyle(Color.Trakke.textSoft)
                }
                .font(.caption)
                .padding(.horizontal, 4)

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func packRow(_ pack: OfflinePackInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pack.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(layerDisplayName(pack.layer))
                    .font(.caption2)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.Trakke.brandTint)
                    .clipShape(Capsule())

                Button {
                    packToDelete = pack
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.red)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "common.delete"))
            }

            HStack {
                Text("z\(pack.minZoom)-\(pack.maxZoom)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textSoft)

                Spacer()

                Text(OfflineMapService.formatBytes(Int64(pack.progress.completedBytes)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textSoft)
            }

            if !pack.progress.isComplete {
                ProgressView(value: pack.progress.percentage, total: 100)
                    .tint(Color.Trakke.brand)

                Text(String(format: "%.0f%%", pack.progress.percentage))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textSoft)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.brand)
                    Text(String(localized: "offline.complete"))
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func layerDisplayName(_ layer: String) -> String {
        switch layer {
        case "topo": return String(localized: "map.layer.topo")
        case "grayscale": return String(localized: "map.layer.grayscale")
        default: return layer
        }
    }

}
