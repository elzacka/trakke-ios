import SwiftUI
import SwiftData

struct PreferencesSheet: View {
    @Bindable var mapViewModel: MapViewModel
    var knowledgeViewModel: KnowledgeViewModel?
    var onDeleteAllData: (() -> Void)?
    var isEmbedded = false
    /// Når true rendres innholdet uten ScrollView/NavigationStack/title –
    /// kalleren har egen scroll (f.eks. en accordion-vert i Mer-fanen).
    var inline = false
    @AppStorage(AppStorageKeys.coordinateFormat) private var coordinateFormat: CoordinateFormat = .dd
    @AppStorage(AppStorageKeys.showWeatherWidget) private var showWeatherWidget = false
    @AppStorage(AppStorageKeys.showZoomControls) private var showZoomControls = false
    @AppStorage(AppStorageKeys.showScaleBar) private var showScaleBar = false
    @AppStorage(AppStorageKeys.showZoomLevel) private var showZoomLevel = false
    @AppStorage(AppStorageKeys.enableRotation) private var enableRotation = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDeleteConfirmation = false

    var body: some View {
        if inline {
            contentVStack
        } else if isEmbedded {
            preferencesContent
        } else {
            NavigationStack {
                preferencesContent
            }
        }
    }

    private var preferencesContent: some View {
        ScrollView {
            contentVStack
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var contentVStack: some View {
        VStack(spacing: .Trakke.cardGap) {
                    // MARK: - Base Layer
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

                    // MARK: - Overlay Layers
                    CardSection(String(localized: "settings.overlays")) {
                        OverlayThumbnailGrid()
                    }

                    // MARK: - Display
                    CardSection(String(localized: "settings.display")) {
                        VStack(spacing: 0) {
                            settingsToggle(
                                label: String(localized: "settings.enableRotation"),
                                isOn: $enableRotation
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showScaleBar"),
                                isOn: $showScaleBar
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showZoomLevel"),
                                isOn: $showZoomLevel
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showWeatherWidget"),
                                isOn: $showWeatherWidget
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showZoomControls"),
                                isOn: $showZoomControls
                            )
                        }
                    }

                    // MARK: - Coordinate Format
                    CardSection(String(localized: "settings.coordinateFormat")) {
                        VStack(spacing: 0) {
                            ForEach(Array(CoordinateFormat.allCases.enumerated()), id: \.element) { index, format in
                                if index > 0 {
                                    Divider().padding(.leading, .Trakke.dividerLeading)
                                }
                                coordinateFormatRow(format)
                            }
                        }
                    }
                    .id("coordinateFormatSection")

                    // MARK: - Handlingsbar: tilbakestill og slett alle data
                    //
                    // Samme ikon-bar-mønster som Naviger-fanene. Slett-knappen
                    // er destruktiv (rød) og krever bekreftelse via dialog –
                    // ingen egen skjerm i mellomliggende steg.
                    HStack(spacing: .Trakke.sm) {
                        Spacer()

                        TrakkeIconButton(
                            systemImage: "arrow.counterclockwise",
                            accessibilityLabel: String(localized: "settings.resetDefaults"),
                            action: resetDefaults
                        )

                        TrakkeIconButton(
                            systemImage: "trash",
                            role: .destructive,
                            accessibilityLabel: String(localized: "settings.deleteAllData"),
                            action: { showDeleteConfirmation = true }
                        )
                        .trakkeDialog(
                            isPresented: $showDeleteConfirmation,
                            title: String(localized: "settings.deleteAllData.title"),
                            message: String(localized: "settings.deleteAllData.message"),
                            primary: .destructive(String(localized: "common.yes")) {
                                deleteAllData()
                            },
                            cancel: .cancel(String(localized: "common.no"))
                        )
                    }

            Spacer(minLength: .Trakke.lg)
        }
        .padding(.horizontal, .Trakke.sheetHorizontal)
        .padding(.top, .Trakke.sheetTop)
    }

    // MARK: - Radio Rows (base layer + coordinate format)

    private func baseLayerRow(_ layer: BaseLayer) -> some View {
        let isSelected = mapViewModel.baseLayer == layer

        return TrakkeMenuRow(
            label: layer.displayName,
            action: { mapViewModel.baseLayer = layer },
            trailing: { TrakkeMenuRowCheckmark(isSelected: isSelected) }
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func coordinateFormatRow(_ format: CoordinateFormat) -> some View {
        let isSelected = coordinateFormat == format

        return TrakkeMenuRow(
            label: format.formatShortTitle,
            subtitle: format.exampleCoordinate,
            subtitleFont: Font.Trakke.captionSoft.monospacedDigit(),
            action: { coordinateFormat = format },
            trailing: { TrakkeMenuRowCheckmark(isSelected: isSelected) }
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func settingsToggle(
        label: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(Font.Trakke.bodyRegular)
        }
        .toggleStyle(.trakke)
        .padding(.vertical, .Trakke.xs)
    }

    // MARK: - Actions

    private func resetDefaults() {
        withAnimation(reduceMotion ? .none : .default) {
            coordinateFormat = .dd
            showWeatherWidget = false
            showZoomControls = false
            showScaleBar = false
            enableRotation = true
            // Alle kartlag av – går via UserDefaults-nøklene slik at både
            // kortene i OverlayThumbnailGrid og MapViewModel plukker det opp.
            // (Dekker også utmRunenett, som den gamle listen hadde glemt.)
            for overlay in OverlayLayer.allCases {
                UserDefaults.standard.set(false, forKey: overlay.storageKey)
            }
            mapViewModel.baseLayer = .topo
        }
    }

    /// GDPR Art. 17 – sletter alle lokale data, cacher og innstillinger.
    /// Flyttet fra DeleteAllDataView (egen skjerm) til en bekreftelses-dialog
    /// for å redusere brukerstøy.
    private func deleteAllData() {
        try? modelContext.delete(model: Route.self)
        try? modelContext.delete(model: Waypoint.self)
        try? modelContext.delete(model: Activity.self)
        try? modelContext.save()

        // Fjern WAL/SHM-filer for å fysisk slette persistert tilstand.
        // SQLite skriver sidecar-filer med bindestrek, ikke punktum-extension.
        if let storeURL = modelContext.container.configurations.first?.url {
            let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
            let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)
        }

        OfflineMapService.shared.deleteAllPacks()
        OfflineMapService.shared.clearTileCache()

        knowledgeViewModel?.clearCache()
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
        APIClient.clearCache()

        // Rydd eksporterte filer fra tmp
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) {
            for file in files where file.pathExtension == "gpx" || file.pathExtension == "geojson" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - CoordinateFormat Description

extension CoordinateFormat {
    /// Komprimert tittel – én linje, uten "(standard)" og fulle navn.
    /// Brukt i radio-rader der formatet vises sammen med eksempel-koordinat.
    var formatShortTitle: String {
        switch self {
        case .dd: return "Desimalgrader (DD)"
        case .dms: return "Grader, minutter, sekunder (DMS)"
        case .utm: return "UTM (sone 33)"
        }
    }

    /// Example coordinate showing how the format looks.
    var exampleCoordinate: String {
        switch self {
        case .dd: return "59.888051, 10.862804"
        case .dms: return "59\u{00B0}53'16.98\"N, 10\u{00B0}51'46.09\"E"
        case .utm: return "33V 604245 6482098"
        }
    }
}
