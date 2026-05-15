import SwiftUI

struct PreferencesSheet: View {
    @Bindable var mapViewModel: MapViewModel
    var knowledgeViewModel: KnowledgeViewModel?
    var onDeleteAllData: (() -> Void)?
    var isEmbedded = false
    /// Når true rendres innholdet uten ScrollView/NavigationStack/title —
    /// kalleren har egen scroll (f.eks. en accordion-vert i Mer-fanen).
    var inline = false
    @AppStorage(AppStorageKeys.coordinateFormat) private var coordinateFormat: CoordinateFormat = .dd
    @AppStorage(AppStorageKeys.showWeatherWidget) private var showWeatherWidget = false
    @AppStorage(AppStorageKeys.showCompass) private var showCompass = false
    @AppStorage(AppStorageKeys.showZoomControls) private var showZoomControls = false
    @AppStorage(AppStorageKeys.showScaleBar) private var showScaleBar = false
    @AppStorage(AppStorageKeys.enableRotation) private var enableRotation = true
    @AppStorage(AppStorageKeys.overlayTurrutebasen) private var overlayTurrutebasen = false
    @AppStorage(AppStorageKeys.overlayHillshading) private var overlayHillshading = false
    @AppStorage(AppStorageKeys.overlayNaturvernomrader) private var overlayNaturvernomrader = false
    @AppStorage(AppStorageKeys.overlayBratthetskart) private var overlayBratthetskart = false
    @AppStorage(AppStorageKeys.overlayUtmRunenett) private var overlayUtmRunenett = false
    @AppStorage(AppStorageKeys.overlayNaturskog) private var overlayNaturskog = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coordinateInfoFormat: CoordinateFormat?

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
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var contentVStack: some View {
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
                            settingsToggle(
                                label: OverlayLayer.hillshading.displayName,
                                isOn: $overlayHillshading
                            )
                            Divider()
                            settingsToggle(
                                label: OverlayLayer.bratthetskart.displayName,
                                isOn: $overlayBratthetskart
                            )
                            Divider()
                            settingsToggle(
                                label: OverlayLayer.naturskog.displayName,
                                isOn: $overlayNaturskog
                            )
                            Divider()
                            settingsToggle(
                                label: OverlayLayer.naturvernomrader.displayName,
                                isOn: $overlayNaturvernomrader
                            )
                            Divider()
                            settingsToggle(
                                label: OverlayLayer.turrutebasen.displayName,
                                isOn: $overlayTurrutebasen
                            )
                            Divider()
                            settingsToggle(
                                label: OverlayLayer.utmRunenett.displayName,
                                isOn: $overlayUtmRunenett
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
                                coordinateFormatRow(format)
                            }
                        }
                    }

                    // MARK: - Reset (ikke destruktiv — bare tilbakestiller togglerne)
                    Button {
                        withAnimation(reduceMotion ? .none : .default) {
                            coordinateFormat = .dd
                            showWeatherWidget = false
                            showCompass = false
                            showZoomControls = false
                            showScaleBar = false
                            enableRotation = true
                            overlayTurrutebasen = false
                            overlayHillshading = false
                            overlayNaturvernomrader = false
                            overlayBratthetskart = false
                            overlayNaturskog = false
                            mapViewModel.baseLayer = .topo
                        }
                    } label: {
                        Text(String(localized: "settings.resetDefaults"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkeSecondary)

                    // MARK: - Slett alle data — egen skjerm (GDPR Art. 17)
                    // Skilt fra togglerne over slik at destruktive valg ikke
                    // ligger ved siden av kosmetiske brytere.
                    NavigationLink {
                        DeleteAllDataView(
                            mapViewModel: mapViewModel,
                            knowledgeViewModel: knowledgeViewModel,
                            onDeleteAllData: onDeleteAllData
                        )
                    } label: {
                        HStack(spacing: .Trakke.md) {
                            Image(systemName: "trash")
                                .font(Font.Trakke.bodyMedium)
                                .foregroundStyle(Color.Trakke.red)
                                .frame(width: 24)
                                .accessibilityHidden(true)

                            Text(String(localized: "settings.deleteAllData"))
                                .font(Font.Trakke.bodyRegular)
                                .foregroundStyle(Color.Trakke.text)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(Font.Trakke.captionSoft)
                                .foregroundStyle(Color.Trakke.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, .Trakke.cardPadH)
                        .padding(.vertical, .Trakke.cardPadV)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
                        .frame(minHeight: .Trakke.touchMin)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

            Spacer(minLength: .Trakke.lg)
        }
        .padding(.horizontal, .Trakke.sheetHorizontal)
        .padding(.top, .Trakke.sheetTop)
    }

    // MARK: - Toggle Row

    private func coordinateFormatRow(_ format: CoordinateFormat) -> some View {
        HStack {
            Toggle(isOn: Binding(
                get: { coordinateFormat == format },
                set: { if $0 { coordinateFormat = format } }
            )) {
                HStack(spacing: .Trakke.xs) {
                    Text(format.formatTitle)
                        .font(Font.Trakke.bodyRegular)
                        .lineLimit(1)

                    Button {
                        coordinateInfoFormat = format
                    } label: {
                        Image(systemName: "info.circle")
                            .font(Font.Trakke.captionSoft)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "settings.format.info"))
                }
            }
            .tint(Color.Trakke.brand)
        }
        .padding(.vertical, .Trakke.xs)
        .trakkeTooltip(isPresented: Binding(
            get: { coordinateInfoFormat == format },
            set: { if !$0 { coordinateInfoFormat = nil } }
        )) {
            TrakkeTooltip(
                title: format.formatTitle,
                text: format.formatTooltip,
                sections: [(
                    header: String(localized: "settings.format.example"),
                    text: format.exampleCoordinate
                )]
            )
        }
    }

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
    /// Short title shown in the settings row.
    var formatTitle: String {
        switch self {
        case .dd: return "DD \u{2013} Desimalgrader (standard)"
        case .dms: return "DMS \u{2013} Grader, minutter, sekunder"
        case .utm: return "UTM \u{2013} Universal Transverse Mercator"
        }
    }

    /// Tooltip description from reliable Norwegian sources.
    var formatTooltip: String {
        let key = "settings.format.\(rawValue).tooltip"
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
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
