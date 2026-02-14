import SwiftUI

struct PreferencesSheet: View {
    @Bindable var mapViewModel: MapViewModel
    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormat = .dd
    @AppStorage("showWeatherWidget") private var showWeatherWidget = true
    @AppStorage("enableRotation") private var enableRotation = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.baseLayer")) {
                    Picker(String(localized: "settings.baseLayer"), selection: $mapViewModel.baseLayer) {
                        ForEach(BaseLayer.allCases) { layer in
                            Text(layer.displayName).tag(layer)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "settings.coordinateFormat")) {
                    Picker(String(localized: "settings.coordinateFormat"), selection: $coordinateFormat) {
                        ForEach(CoordinateFormat.allCases) { format in
                            VStack(alignment: .leading) {
                                Text(format.displayName)
                                Text(format.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(String(localized: "settings.display")) {
                    Toggle(String(localized: "settings.showWeatherWidget"), isOn: $showWeatherWidget)
                    Toggle(String(localized: "settings.enableRotation"), isOn: $enableRotation)
                }

                Section {
                    Button(String(localized: "settings.resetDefaults"), role: .destructive) {
                        coordinateFormat = .dd
                        showWeatherWidget = true
                        enableRotation = true
                        mapViewModel.baseLayer = .topo
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - CoordinateFormat Description

extension CoordinateFormat {
    var description: String {
        switch self {
        case .dd: return String(localized: "settings.format.dd.description")
        case .dms: return String(localized: "settings.format.dms.description")
        case .ddm: return String(localized: "settings.format.ddm.description")
        case .utm: return String(localized: "settings.format.utm.description")
        case .mgrs: return String(localized: "settings.format.mgrs.description")
        }
    }
}
