import SwiftUI

struct MapLayerPicker: View {
    @Binding var selectedLayer: BaseLayer

    var body: some View {
        Picker(String(localized: "settings.baseLayer"), selection: $selectedLayer) {
            ForEach(BaseLayer.allCases) { layer in
                Text(layer.displayName).tag(layer)
            }
        }
        .pickerStyle(.segmented)
    }
}
