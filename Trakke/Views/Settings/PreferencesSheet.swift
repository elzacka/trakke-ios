import SwiftUI
import SwiftData

struct PreferencesSheet: View {
    @Bindable var mapViewModel: MapViewModel
    var knowledgeViewModel: KnowledgeViewModel?
    var isEmbedded = false
    @AppStorage(AppStorageKeys.coordinateFormat) private var coordinateFormat: CoordinateFormat = .dd
    @AppStorage(AppStorageKeys.showWeatherWidget) private var showWeatherWidget = false
    @AppStorage(AppStorageKeys.showCompass) private var showCompass = true
    @AppStorage(AppStorageKeys.showZoomControls) private var showZoomControls = false
    @AppStorage(AppStorageKeys.showScaleBar) private var showScaleBar = false
    @AppStorage(AppStorageKeys.enableRotation) private var enableRotation = true
    @AppStorage(AppStorageKeys.overlayTurrutebasen) private var overlayTurrutebasen = false
    @AppStorage(AppStorageKeys.overlayHillshading) private var overlayHillshading = false
    @AppStorage(AppStorageKeys.overlayNaturvernomrader) private var overlayNaturvernomrader = false
    @AppStorage(AppStorageKeys.overlayNaturskog) private var overlayNaturskog = false
    @AppStorage(AppStorageKeys.naturskogLayerType) private var naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        if isEmbedded {
            preferencesContent
        } else {
            NavigationStack {
                preferencesContent
            }
        }
    }

    private var preferencesContent: some View {
        ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    // MARK: - Base Layer
                    CardSection(String(localized: "settings.baseLayer")) {
                        Picker(String(localized: "settings.baseLayer"), selection: $mapViewModel.baseLayer) {
                            ForEach(BaseLayer.allCases) { layer in
                                Text(layer.displayName).tag(layer)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // MARK: - Overlay Layers
                    CardSection(String(localized: "settings.overlays")) {
                        VStack(spacing: 0) {
                            // Terrain overlays
                            Text(String(localized: "settings.overlays.terrain"))
                                .font(Font.Trakke.caption)
                                .foregroundStyle(Color.Trakke.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, .Trakke.xs)

                            settingsToggle(
                                label: OverlayLayer.hillshading.displayName,
                                isOn: $overlayHillshading
                            )

                            Divider()
                                .padding(.top, .Trakke.md)

                            // Nature and travel overlays
                            Text(String(localized: "settings.overlays.nature"))
                                .font(Font.Trakke.caption)
                                .foregroundStyle(Color.Trakke.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, .Trakke.md)
                                .padding(.bottom, .Trakke.xs)

                            settingsToggle(
                                label: String(localized: "map.overlay.naturskog"),
                                isOn: $overlayNaturskog
                            )
                            if overlayNaturskog {
                                naturskogSubPicker
                            }
                            Divider()
                            settingsToggle(
                                label: OverlayLayer.naturvernomrader.displayName,
                                isOn: $overlayNaturvernomrader
                            )
                        }
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
                                label: String(localized: "settings.showCompass"),
                                isOn: $showCompass
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showScaleBar"),
                                isOn: $showScaleBar
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
                                Button {
                                    coordinateFormat = format
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                                            Text(format.displayName)
                                                .font(Font.Trakke.bodyMedium)
                                                .foregroundStyle(Color.Trakke.text)
                                            Text(format.formatDescription)
                                                .font(Font.Trakke.caption)
                                                .foregroundStyle(Color.Trakke.textTertiary)
                                        }
                                        Spacer()
                                        if coordinateFormat == format {
                                            Image(systemName: "checkmark")
                                                .font(Font.Trakke.bodyMedium)
                                                .foregroundStyle(Color.Trakke.brand)
                                        }
                                    }
                                    .frame(minHeight: .Trakke.touchMin)
                                    .contentShape(Rectangle())
                                }
                                .accessibilityAddTraits(coordinateFormat == format ? .isSelected : [])
                            }
                        }
                    }

                    // MARK: - Reset
                    Button {
                        withAnimation(reduceMotion ? .none : .default) {
                            coordinateFormat = .dd
                            showWeatherWidget = false
                            showCompass = true
                            showZoomControls = false
                            showScaleBar = false
                            enableRotation = true
                            overlayTurrutebasen = false
                            overlayHillshading = false
                            overlayNaturvernomrader = false
                            overlayNaturskog = false
                            naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
                            mapViewModel.baseLayer = .topo
                        }
                    } label: {
                        Text(String(localized: "settings.resetDefaults"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkeDanger)

                    // MARK: - Delete All Data (GDPR Art. 17)
                    Button {
                        showDeleteAllConfirmation = true
                    } label: {
                        Label(String(localized: "settings.deleteAllData"), systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkeDanger)
                    .confirmationDialog(
                        String(localized: "settings.deleteAllData.title"),
                        isPresented: $showDeleteAllConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "settings.deleteAllData.confirm"), role: .destructive) {
                            deleteAllData()
                        }
                    } message: {
                        Text(String(localized: "settings.deleteAllData.message"))
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Delete All Data

    private func deleteAllData() {
        // Delete all SwiftData records (GDPR Art. 17)
        try? modelContext.delete(model: Route.self)
        try? modelContext.delete(model: Waypoint.self)
        try? modelContext.delete(model: Activity.self)
        try? modelContext.save()

        // Delete offline map packs
        OfflineMapService.shared.deleteAllPacks()

        // Delete knowledge packs (SQLite databases, metadata, catalog cache)
        knowledgeViewModel?.deleteAllPacks()

        // Clear in-memory service caches
        BundledPOIService.clearCache()

        // Reset all preferences to defaults
        coordinateFormat = .dd
        showWeatherWidget = false
        showCompass = true
        showZoomControls = false
        showScaleBar = false
        enableRotation = true
        overlayTurrutebasen = false
        overlayHillshading = false
        overlayNaturvernomrader = false
        overlayNaturskog = false
        naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
        mapViewModel.baseLayer = .topo
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.navigationSessionActive)

        // Clean up temp directory
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) {
            for file in files where file.pathExtension == "gpx" {
                try? FileManager.default.removeItem(at: file)
            }
        }

        dismiss()
    }

    // MARK: - Naturskog Sub-Picker

    private var naturskogSubPicker: some View {
        VStack(spacing: 0) {
            ForEach(Array(OverlayLayer.naturskogLayers.enumerated()), id: \.element) { index, layer in
                if index > 0 {
                    Divider().padding(.leading, .Trakke.sheetHorizontal)
                }
                Button {
                    naturskogLayerType = layer.rawValue
                } label: {
                    HStack {
                        Text(layer.displayName)
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.text)
                        Spacer()
                        if naturskogLayerType == layer.rawValue {
                            Image(systemName: "checkmark")
                                .font(Font.Trakke.bodyMedium)
                                .foregroundStyle(Color.Trakke.brand)
                        }
                    }
                    .frame(minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(naturskogLayerType == layer.rawValue ? .isSelected : [])
            }
        }
        .padding(.leading, .Trakke.sheetHorizontal)
        .padding(.top, .Trakke.xs)
    }

    // MARK: - Toggle Row

    private func settingsToggle(
        label: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(Font.Trakke.bodyRegular)
        }
        .tint(Color.Trakke.brand)
        .padding(.vertical, .Trakke.xs)
    }
}

// MARK: - CoordinateFormat Description

extension CoordinateFormat {
    var formatDescription: String {
        switch self {
        case .dd: return String(localized: "settings.format.dd.description")
        case .dms: return String(localized: "settings.format.dms.description")
        case .ddm: return String(localized: "settings.format.ddm.description")
        case .utm: return String(localized: "settings.format.utm.description")
        case .mgrs: return String(localized: "settings.format.mgrs.description")
        }
    }
}
