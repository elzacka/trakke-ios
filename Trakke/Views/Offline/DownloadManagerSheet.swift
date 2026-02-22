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
                HStack(spacing: .Trakke.sm) {
                    Image(systemName: "info.circle")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                    Text(String(localized: "offline.autoUseHint"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, .Trakke.xs)

                CardSection(String(localized: "offline.packs")) {
                    ForEach(Array(viewModel.packs.enumerated()), id: \.element.id) { index, pack in
                        if index > 0 {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                        }
                        packRow(pack)
                    }
                }

                // Storage info
                HStack {
                    Text(String(localized: "offline.totalStorage"))
                        .foregroundStyle(Color.Trakke.textTertiary)
                    Spacer()
                    let totalBytes = viewModel.packs.reduce(Int64(0)) { $0 + Int64($1.progress.completedBytes) }
                    Text(OfflineMapService.formatBytes(totalBytes))
                        .monospacedDigit()
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
                .font(Font.Trakke.caption)
                .padding(.horizontal, .Trakke.xs)

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func packRow(_ pack: OfflinePackInfo) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.rowVertical) {
            HStack {
                Text(pack.name)
                    .font(Font.Trakke.bodyMedium)
                Spacer()
                Text(layerDisplayName(pack.layer))
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.Trakke.brandTint)
                    .clipShape(Capsule())

                Button {
                    packToDelete = pack
                } label: {
                    Image(systemName: "trash")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.red)
                        .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "common.delete"))
            }

            HStack {
                Text("z\(pack.minZoom)-\(pack.maxZoom)")
                    .font(Font.Trakke.caption.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textTertiary)

                Spacer()

                Text(OfflineMapService.formatBytes(Int64(pack.progress.completedBytes)))
                    .font(Font.Trakke.caption.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textTertiary)
            }

            if !pack.progress.isComplete {
                ProgressView(value: pack.progress.percentage, total: 100)
                    .tint(Color.Trakke.brand)

                Text(String(format: "%.0f%%", pack.progress.percentage))
                    .font(Font.Trakke.captionSoft.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textTertiary)
            } else {
                HStack(spacing: .Trakke.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.brand)
                    Text(String(localized: "offline.complete"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
            }
        }
        .padding(.vertical, .Trakke.xs)
    }

    private func layerDisplayName(_ layer: String) -> String {
        switch layer {
        case "topo": return String(localized: "map.layer.topo")
        case "grayscale": return String(localized: "map.layer.grayscale")
        default: return layer
        }
    }

}
