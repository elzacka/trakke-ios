import SwiftUI

struct DownloadManagerSheet: View {
    @Bindable var viewModel: OfflineViewModel
    var onNewDownload: (() -> Void)?
    var isEmbedded: Bool = false
    var dismissSheet: (() -> Void)?
    /// Viser området på kartet og lukker menyen. Uten denne forteller lista
    /// bare et navn – ikke hvilket terreng du faktisk har liggende.
    var onShowOnMap: ((OfflinePackInfo) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var packToDelete: OfflinePackInfo?
    @State private var packToRename: OfflinePackInfo?
    @State private var newName: String = ""

    var body: some View {
        Group {
            if isEmbedded {
                innerContent
            } else {
                NavigationStack { innerContent }
            }
        }
    }

    private var innerContent: some View {
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
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "offline.manager.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onNewDownload?()
                    if isEmbedded {
                        dismissSheet?()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "offline.download"))
            }
        }
        .trakkeDialog(
            isPresented: Binding(
                get: { packToDelete != nil },
                set: { if !$0 { packToDelete = nil } }
            ),
            title: String(localized: "offline.deleteConfirm.title"),
            message: packToDelete.map { String(localized: "offline.deleteConfirm.message \($0.name)") },
            primary: .destructive(String(localized: "common.yes")) {
                if let pack = packToDelete {
                    viewModel.deletePack(pack)
                }
                packToDelete = nil
            },
            cancel: .cancel(String(localized: "common.no")) {
                packToDelete = nil
            }
        )
        // Samme mønster som å endre navn på en kategori i Steder.
        .alert(String(localized: "offline.renameTitle"), isPresented: Binding(
            get: { packToRename != nil },
            set: { if !$0 { packToRename = nil; newName = "" } }
        )) {
            TextField(String(localized: "offline.areaName"), text: $newName)
            Button(String(localized: "common.save")) {
                if let pack = packToRename {
                    viewModel.renamePack(pack, to: newName)
                }
                packToRename = nil
                newName = ""
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                packToRename = nil
                newName = ""
            }
        }
    }

    private var packList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                // Info about how offline maps work
                Text(String(localized: "offline.autoUseHint"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .Trakke.xs)

                CardSection(String(localized: "offline.packs")) {
                    ForEach(viewModel.packs) { pack in
                        if viewModel.packs.first?.id != pack.id {
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
        .background(Color.Trakke.background)
    }

    private func packRow(_ pack: OfflinePackInfo) -> some View {
        packRowContent(pack)
            // Hele raden er trykkbar, men bare når nedlastingen er ferdig –
            // et halvlastet område har ingen meningsfull utstrekning å vise.
            .contentShape(Rectangle())
            .onTapGesture {
                guard pack.progress.isComplete, let onShowOnMap else { return }
                onShowOnMap(pack)
            }
            .contextMenu {
                Button {
                    packToRename = pack
                    newName = pack.name
                } label: {
                    Label(String(localized: "offline.rename"), systemImage: "pencil")
                }
                if pack.progress.isComplete {
                    Button {
                        viewModel.refreshPack(pack)
                    } label: {
                        Label(String(localized: "offline.refresh"), systemImage: "arrow.clockwise")
                    }
                }
                // «Slett» gjentas ikke her – papirkurven i raden er alltid
                // synlig, og appens regel er at trykk-og-hold ikke dupliserer
                // en handling som allerede står framme.
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(
                pack.progress.isComplete
                    ? String(localized: "offline.showOnMap")
                    : ""
            )
    }

    private func packRowContent(_ pack: OfflinePackInfo) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.rowVertical) {
            HStack {
                Text(pack.name)
                    .font(Font.Trakke.bodyMedium)
                if viewModel.refreshingPackIds.contains(pack.id) {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(.leading, .Trakke.xs)
                }
                Spacer()
                Text(layerDisplayName(pack.layer))
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .padding(.horizontal, .Trakke.badgePadH)
                    .padding(.vertical, .Trakke.badgePadV)
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
                Text(OfflineMapService.zoomDescription(maxZoom: pack.maxZoom))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)

                Spacer()

                Text(OfflineMapService.formatBytes(Int64(pack.progress.completedBytes)))
                    .font(Font.Trakke.caption.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textTertiary)
            }

            if viewModel.isErrored(pack) {
                HStack(spacing: .Trakke.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.red)
                    Text(String(localized: "offline.downloadError"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.red)
                    Spacer()
                    Button(String(localized: "offline.retry")) {
                        viewModel.retryPack(pack)
                    }
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.brand)
                    .buttonStyle(.plain)
                }
            } else if !pack.progress.isComplete {
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
