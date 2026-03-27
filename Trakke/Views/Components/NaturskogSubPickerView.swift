import SwiftUI

struct NaturskogSubPickerView: View {
    @Binding var selectedLayerType: String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(OverlayLayer.naturskogLayers.enumerated()), id: \.element) { index, layer in
                if index > 0 {
                    Divider().padding(.leading, .Trakke.sheetHorizontal)
                }
                Button {
                    selectedLayerType = layer.rawValue
                } label: {
                    HStack {
                        Text(layer.displayName)
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.text)
                        Spacer()
                        if selectedLayerType == layer.rawValue {
                            Image(systemName: "checkmark")
                                .font(Font.Trakke.bodyMedium)
                                .foregroundStyle(Color.Trakke.brand)
                        }
                    }
                    .frame(minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(selectedLayerType == layer.rawValue ? .isSelected : [])
            }
        }
        .padding(.leading, .Trakke.sheetHorizontal)
        .padding(.top, .Trakke.xs)
    }
}
