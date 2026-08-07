import SwiftUI

struct DownloadManagerSheet: View {
    @Bindable var viewModel: OfflineViewModel
    var isEmbedded: Bool = false
    /// Viser området på kartet og lukker menyen. Uten denne forteller lista
    /// bare et navn – ikke hvilket terreng du faktisk har liggende.
    var onShowOnMap: ((OfflinePackInfo) -> Void)?
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
                    Text(String(localized: "offline.rename"))
                }
                if pack.progress.isComplete {
                    Button {
                        viewModel.refreshPack(pack)
                    } label: {
                        Text(String(localized: "offline.refresh"))
                    }
                } else if !pack.isDownloading {
                    Button {
                        viewModel.resumePack(pack)
                    } label: {
                        Text(String(localized: "offline.resume"))
                    }
                }
                Button(role: .destructive) {
                    packToDelete = pack
                } label: {
                    Text(String(localized: "common.delete"))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(
                pack.progress.isComplete
                    ? String(localized: "offline.showOnMap")
                    : ""
            )
    }

    /// To linjer: navn og størrelse øverst, kartlag og tilstand under.
    /// Tidligere brukte en ferdig pakke fire linjer, hvorav én bare sa
    /// «Fullført» med et grønt flueben – støy for det som er normaltilstanden.
    /// Med flere områder ble lista unødig lang å bla gjennom.
    private func packRowContent(_ pack: OfflinePackInfo) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
            HStack {
                Text(pack.name)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)
                if viewModel.refreshingPackIds.contains(pack.id) {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(.leading, .Trakke.xs)
                }
                Spacer()
                Text(OfflineMapService.formatBytes(Int64(pack.progress.completedBytes)))
                    .font(Font.Trakke.caption.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textTertiary)
            }

            HStack(spacing: .Trakke.sm) {
                Text(subtitle(for: pack))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(
                        viewModel.isErrored(pack) ? Color.Trakke.red : Color.Trakke.textTertiary
                    )

                Spacer()

                if viewModel.isErrored(pack) {
                    Button(String(localized: "offline.retry")) {
                        viewModel.retryPack(pack)
                    }
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.brand)
                    .buttonStyle(.plain)
                }
            }

            // Framdriftslinja står bare mens noe faktisk skjer. På en stanset
            // pakke er den en linje som aldri beveger seg; tallet i
            // undertittelen sier det samme uten å ta plass.
            if pack.isDownloading && !pack.progress.isComplete {
                ProgressView(value: pack.progress.percentage, total: 100)
                    .tint(Color.Trakke.brand)
            }
        }
        .padding(.vertical, .Trakke.xs)
    }

    /// «Topografisk · Detaljert» når alt er nede, ellers med tilstanden bakerst.
    private func subtitle(for pack: OfflinePackInfo) -> String {
        let layer = layerDisplayName(pack.layer)
        if viewModel.isErrored(pack) {
            return layer + " · " + String(localized: "offline.downloadError")
        }
        if pack.progress.isComplete {
            return layer + " · " + OfflineMapService.zoomDescription(maxZoom: pack.maxZoom)
        }
        let percent = String(format: "%.0f", pack.progress.percentage)
        let state = pack.isDownloading
            ? String(localized: "offline.downloading")
            : String(localized: "offline.stopped")
        return layer + " · " + state + " " + percent + " %"
    }

    private func layerDisplayName(_ layer: String) -> String {
        switch layer {
        case "topo": return String(localized: "map.layer.topo")
        case "grayscale": return String(localized: "map.layer.grayscale")
        default: return layer
        }
    }

}
