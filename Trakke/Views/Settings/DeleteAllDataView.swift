import SwiftUI
import SwiftData

/// Egen skjerm for sletting av alle data (GDPR Art. 17).
/// Skilt fra Preferences slik at destruktive handlinger ikke ligger ved siden
/// av visningsinnstillinger der de kan trykkes ved et uhell.
struct DeleteAllDataView: View {
    @Bindable var mapViewModel: MapViewModel
    var knowledgeViewModel: KnowledgeViewModel?
    var onDeleteAllData: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Trakke.cardGap) {
                CardSection(String(localized: "settings.deleteAllData.title")) {
                    Text(String(localized: "settings.deleteAllData.message"))
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, .Trakke.sm)
                }

                Button {
                    showConfirmation = true
                } label: {
                    Label(
                        String(localized: "settings.deleteAllData"),
                        systemImage: "trash"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.trakkeDanger)
                .trakkeDialog(
                    isPresented: $showConfirmation,
                    title: String(localized: "settings.deleteAllData.title"),
                    message: String(localized: "settings.deleteAllData.message"),
                    primary: .destructive(String(localized: "common.yes")) {
                        deleteAllData()
                    },
                    cancel: .cancel(String(localized: "common.no"))
                )

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "settings.deleteAllData"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Slett alt (GDPR Art. 17)

    private func deleteAllData() {
        try? modelContext.delete(model: Route.self)
        try? modelContext.delete(model: Waypoint.self)
        try? modelContext.delete(model: Activity.self)
        try? modelContext.save()

        // Fjern WAL/SHM-filer for å fysisk slette persistert tilstand
        if let storeURL = modelContext.container.configurations.first?.url {
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)
        }

        OfflineMapService.shared.deleteAllPacks()
        OfflineMapService.shared.clearTileCache()

        knowledgeViewModel?.deleteAllPacks()
        if knowledgeViewModel == nil {
            Task { await RemoteArticleService().clearCache() }
        }

        BundledPOIService.clearCache()
        Task { await ArtsdatabankenImageService.default.clearCache() }

        onDeleteAllData?()

        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        mapViewModel.baseLayer = .topo

        URLCache.shared.removeAllCachedResponses()

        // Rydd eksporterte filer fra tmp
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) {
            for file in files where file.pathExtension == "gpx" || file.pathExtension == "geojson" {
                try? FileManager.default.removeItem(at: file)
            }
        }

        dismiss()
    }
}
