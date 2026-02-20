import SwiftUI

struct PreferencesSheet: View {
    @Bindable var mapViewModel: MapViewModel
    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormat = .dd
    @AppStorage("showWeatherWidget") private var showWeatherWidget = false
    @AppStorage("showCompass") private var showCompass = true
    @AppStorage("showZoomControls") private var showZoomControls = false
    @AppStorage("showScaleBar") private var showScaleBar = false
    @AppStorage("enableRotation") private var enableRotation = true
    @AppStorage("overlayTurrutebasen") private var overlayTurrutebasen = false
    @AppStorage("overlayNaturskog") private var overlayNaturskog = false
    @AppStorage("naturskogLayerType") private var naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
                            settingsToggle(
                                label: OverlayLayer.turrutebasen.displayName,
                                isOn: $overlayTurrutebasen
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "map.overlay.naturskog"),
                                isOn: $overlayNaturskog
                            )
                            if overlayNaturskog {
                                VStack(spacing: 0) {
                                    ForEach(Array(OverlayLayer.naturskogLayers.enumerated()), id: \.element) { index, layer in
                                        if index > 0 {
                                            Divider().padding(.leading, 20)
                                        }
                                        Button {
                                            naturskogLayerType = layer.rawValue
                                        } label: {
                                            HStack {
                                                Text(layer.displayName)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                if naturskogLayerType == layer.rawValue {
                                                    Image(systemName: "checkmark")
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(Color.Trakke.brand)
                                                }
                                            }
                                            .frame(minHeight: 44)
                                            .contentShape(Rectangle())
                                        }
                                        .accessibilityAddTraits(naturskogLayerType == layer.rawValue ? .isSelected : [])
                                    }
                                }
                                .padding(.leading, 20)
                                .padding(.top, 4)
                            }
                        }
                    }

                    // MARK: - Display
                    CardSection(String(localized: "settings.display")) {
                        VStack(spacing: 0) {
                            settingsToggle(
                                label: String(localized: "settings.showWeatherWidget"),
                                isOn: $showWeatherWidget
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showCompass"),
                                isOn: $showCompass
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showZoomControls"),
                                isOn: $showZoomControls
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.showScaleBar"),
                                isOn: $showScaleBar
                            )
                            Divider()
                            settingsToggle(
                                label: String(localized: "settings.enableRotation"),
                                isOn: $enableRotation
                            )
                        }
                    }

                    // MARK: - Coordinate Format
                    CardSection(String(localized: "settings.coordinateFormat")) {
                        VStack(spacing: 0) {
                            ForEach(Array(CoordinateFormat.allCases.enumerated()), id: \.element) { index, format in
                                if index > 0 {
                                    Divider().padding(.leading, 4)
                                }
                                Button {
                                    coordinateFormat = format
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(format.displayName)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text(format.formatDescription)
                                                .font(.caption)
                                                .foregroundStyle(Color.Trakke.textSoft)
                                        }
                                        Spacer()
                                        if coordinateFormat == format {
                                            Image(systemName: "checkmark")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.Trakke.brand)
                                        }
                                    }
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .accessibilityAddTraits(coordinateFormat == format ? .isSelected : [])
                            }
                        }
                    }

                    // MARK: - Reset
                    Button {
                        withAnimation {
                            coordinateFormat = .dd
                            showWeatherWidget = false
                            showCompass = true
                            showZoomControls = false
                            showScaleBar = false
                            enableRotation = true
                            overlayTurrutebasen = false
                            overlayNaturskog = false
                            naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
                            mapViewModel.baseLayer = .topo
                        }
                    } label: {
                        Text(String(localized: "settings.resetDefaults"))
                    }
                    .buttonStyle(.trakkeDanger)

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Toggle Row

    private func settingsToggle(
        label: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.subheadline)
        }
        .tint(Color.Trakke.brand)
        .padding(.vertical, 4)
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
